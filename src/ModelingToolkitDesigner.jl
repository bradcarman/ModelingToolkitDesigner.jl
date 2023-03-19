module ModelingToolkitDesigner
using GLMakie
using ModelingToolkit
using FilterHelpers
using FileIO

#=
TODO:

- scale the labels
- add this repo to my GitHub account
=#


# struct Parameter

# end

# struct State

# end

# struct Connector
#     type::Symbol
#     color::Symbol
#     wall::Symbol
# end

const Δh = 0.05

mutable struct ODESystemDesign
    # parameters::Vector{Parameter}
    # states::Vector{State}
    namespace::Union{Symbol, Nothing}
    system::ODESystem
    systems::Vector{ODESystemDesign}
    connectors::Vector{ODESystemDesign}
    connections::Vector{Tuple{ODESystemDesign, ODESystemDesign}}
    equations::Vector{Equation}
    xy::Observable{Tuple{Float64, Float64}}
    icon::Union{String, Nothing}
    color::Observable{Symbol}
    wall::Observable{Symbol}
end

function ODESystemDesign(rootnamespace::Union{Symbol, Nothing}, system::ODESystem, design::Union{Vector{Pair{ODESystem, NamedTuple}}, Dict}; x=0.0, y=0.0, icon=nothing, wall=:E)

    if design isa Vector{Pair{ODESystem, NamedTuple}}
        pairs = design
        design = Dict()
        for (sys, args) in pairs
            push!(design, sys.name => args)
        end
    end

    # Main._x[] = design

    println("system: $(system.name)")
    if !isnothing(rootnamespace)
        namespace = Symbol(rootnamespace, "₊", system.name)
    else
        namespace = system.name
    end

    systems = filter(x-> typeof(x) == ODESystem, ModelingToolkit.get_systems(system))
    

    children = ODESystemDesign[]
    connectors = ODESystemDesign[]
    connections = Tuple{ODESystemDesign, ODESystemDesign}[]
    if !isempty(systems)
        children_ = filter(x->!ModelingToolkit.isconnector(x), systems)
        if !isempty(children_)
    
            for (i,c) in enumerate(children_)

                key = Symbol(namespace, "₊", c.name)
                kwargs = if haskey(design, key)
                    design[key]
                else
                    NamedTuple()
                end
                push!(children, ODESystemDesign(namespace, c, design; kwargs...))                
            end
        end

        connectors_ = filter(x->ModelingToolkit.isconnector(x), systems)
        if !isempty(connectors_)
            
            for (i,c) in enumerate(connectors_)

                key = Symbol(namespace, "₊", c.name)
                kwargs = if haskey(design, key)
                    design[key]
                else
                    NamedTuple()
                end

                
                push!(connectors, ODESystemDesign(namespace, c, design; kwargs...))                
            end
        end

        for eq in equations(system)

            if eq.rhs isa Connection

                conns = []
                for connector in eq.rhs.systems

                    parent, child = split(string(connector.name), '₊')                   
                    child_design = filtersingle(x->string(x.system.name) == parent, children)
                    connector_design = filtersingle(x->string(x.system.name) == child, child_design.connectors)

                    push!(conns, connector_design)
                end

                for i=2:length(conns)
                    push!(connections, (conns[i-1], conns[i]))
                end


            end


        end
        
        
    
    end

    xy= Observable((x,y))



    return ODESystemDesign(rootnamespace, system, children, connectors, connections, Equation[], xy, icon, Observable(get_color(system)), Observable(wall))
end

# connector => box
const selected_connectors = ODESystemDesign[]
const selected_design = Ref{ODESystemDesign}()
const line_system_map = Ref{Dict}()
const point_connector_map = Ref{Dict}()
const ax = Ref{Axis}()
 
function Base.isapprox(a::Tuple{Float64, Float64}, b::Tuple{Float64, Float64}; atol)

    r1 = isapprox(a[1], b[1]; atol)
    r2 = isapprox(a[2], b[2]; atol)

    return all([r1, r2])
end

get_change(::Val) = (0.0, 0.0)
get_change(::Val{Keyboard.up}) = (0.0, +0.01)
get_change(::Val{Keyboard.down}) = (0.0, -0.01)
get_change(::Val{Keyboard.left}) = (-0.01, 0.0)
get_change(::Val{Keyboard.right}) = (+0.01, 0.0)

function view(model::ODESystemDesign)

    empty!(selected_connectors)

    fig = Figure()

    ax[] = Axis(fig[1:10,1:10], aspect = DataAspect(), 
                    yticksvisible=false, 
                    xticksvisible=false, 
                    yticklabelsvisible =false, 
                    xticklabelsvisible =false,
                    xgridvisible=false,
                    ygridvisible=false, 
                    bottomspinecolor = :transparent,
                    leftspinecolor = :transparent,
                    rightspinecolor = :transparent,
                    topspinecolor = :transparent)


    for system in model.systems
        add_system(system)
        notify(system.xy)
        for connector in system.connectors
            notify(connector.wall)
        end
    end

    for connection in model.connections
        connect(connection)
    end


    on(events(fig).mousebutton, priority = 2) do event

        println(". $(event.button) & $(event.action)")

        if event.button == Mouse.left && event.action == Mouse.press
            
            # if Keyboard.s in events(fig).keyboardstate
                # Delete marker
                plt, i = pick(fig)
                println("$plt i=$i")

                if !isnothing(plt)

                    if plt isa Image

                        image = plt
                        xobservable = image[1]
                        xvalues = xobservable[]
                        yobservable = image[2]
                        yvalues = yobservable[]


                        x = xvalues[1] + 0.05
                        y = yvalues[1] + 0.05

                        selected_system = filtersingle(s->isapprox(s.xy[], (x,y); atol=1e-3), model.systems)

                        selected_system.color[] = :pink

                    elseif plt isa Lines

                    elseif plt isa Scatter

                        point = plt
                        observable = point[1]
                        values = observable[]
                        geometry_point = Float64.(values[1])
                    
                        x = geometry_point[1]
                        y = geometry_point[2]
                        
                        all_connectors = vcat([s.connectors for s in model.systems]...)
                        selected_connector = filtersingle(c->isapprox(c.xy[], (x,y); atol=1e-3), all_connectors)
                        
                        selected_connector.color[] = :pink

                    elseif plt isa Mesh



                    end

                    


                    # println("i=$i plt[i]=$(plt[i])")
                    # plt.color = :pink
                end
                
            

            Consume(true)
        end

        return Consume(false)
    end
    
    
    connect_button = Button(fig[11,1]; label= "connect")
    on(connect_button.clicks) do clicks
        connect(model)
    end

    clear_selection_button = Button(fig[11,2]; label="clear selection")
    on(clear_selection_button.clicks) do clicks
        for system in model.systems
            for connector in system.connectors
                connector.color[] = get_color(connector.system)
            end
            system.color[] = :black
        end
    end

    on(events(fig).keyboardbutton) do event
        if event.action == Keyboard.press
            change = get_change(Val(event.key))
            
            if change != (0.0, 0.0)
                for system in model.systems
                    if system.color[] == :pink
                        
                        xc = system.xy[][1]
                        yc = system.xy[][2]

                        system.xy[] = (xc + change[1], yc + change[2])
                        
                    end
                end

                reset_limits!(ax[])

                return Consume(true)
            end
        end

        println(event.key)
    end

    next_wall_button = Button(fig[11,3]; label="move node")
    on(next_wall_button.clicks) do clicks
        for system in model.systems
            for connector in system.connectors
                if connector.color[] == :pink
                    if connector.wall[] == :N 
                        connector.wall[] = :E
                    elseif connector.wall[] == :W
                        connector.wall[] = :N
                    elseif connector.wall[] == :S
                        connector.wall[] = :W
                    elseif connector.wall[] == :E
                        connector.wall[] = :S
                    end
                end
            end
        end
    end

    fig

end



function connect(model::ODESystemDesign)



    all_connectors = vcat([s.connectors for s in model.systems]...)

    selected_connectors = ODESystemDesign[]



    local color
    for connector in all_connectors

        if connector.color[] == :pink

            
            push!(selected_connectors, connector)
       


            color = get_color(connector)
            connector.color[] = color
            
        end

        if length(selected_connectors) > 1
            connect((selected_connectors[1], selected_connectors[2]))
            push!(model.connections, (selected_connectors[1], selected_connectors[2]))
        end
    end

end



function connect(connection::Tuple{ODESystemDesign, ODESystemDesign})

    xs = Observable(Float64[])
    ys = Observable(Float64[])

    update = () -> begin
        empty!(xs[])
        empty!(ys[])
        for connector in connection

            push!(xs[], connector.xy[][1])
            push!(ys[], connector.xy[][2])
        end
        notify(xs)
        notify(ys)
    end

    for connector in connection
        on(connector.xy) do val
            update()
        end
    end

    update()  


    lines!(ax[], xs, ys; color=connection[1].color)
end





get_wall(system::ODESystemDesign) = system.wall[]


get_text_alignment(wall::Symbol) = get_text_alignment(Val(wall))
get_text_alignment(::Val{:E}) = (:left, :top)
get_text_alignment(::Val{:W}) = (:right, :top)
get_text_alignment(::Val{:S}) = (:left, :top)
get_text_alignment(::Val{:N}) = (:right, :top)


get_color(system_design::ODESystemDesign) = get_color(system_design.system)
function get_color(system::ODESystem)
    sv = states(system)
    if sum(string.(sv) .== ["p(t)" "dm(t)"]) == 2
        return :blue
    elseif sum(string.(sv) .== ["f(t)" "v(t)"]) == 2
        return :green
    else 
        return :black
    end
end


function draw_box(system::ODESystemDesign)
    
    xo = Observable(zeros(5))
    yo = Observable(zeros(5))
    
    on(system.xy) do val
        x = val[1]
        y = val[2]
        xo[], yo[] = box(x,y)
    end

    lines!(ax[], xo, yo; color=system.color)
end

function draw_icon(system::ODESystemDesign)

    xo = Observable(zeros(2))
    yo = Observable(zeros(2))

    on(system.xy) do val

        x = val[1]
        y = val[2]

        xo[] = [x - Δh, x + Δh]
        yo[] = [y - Δh, y + Δh]

    end

    
    if !isnothing(system.icon)
        img = load(system.icon)       
        image!(ax[], xo, yo, rotr90(img))
    end   
end

function draw_label(system::ODESystemDesign)
    
    xo = Observable(0.0)
    yo = Observable(0.0)

    on(system.xy) do val

        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y - 0.1

    end

    text!(ax[], xo, yo; text=string(system.system.name), align=(:center, :bottom))
end

function draw_nodes(system::ODESystemDesign)
  
    for connector in system.connectors

        on(connector.wall) do val
            println("updating node: $(system.system.name) $(connector.system.name)")
            connectors_on_wall = filter(x->x.wall[] == val, system.connectors)

            n_items = length(connectors_on_wall)
            delta = 2*Δh/(n_items+1)

            for i=1:n_items
                x,y = get_node_position(val, delta, i)
                connectors_on_wall[i].xy[] = (x,y)
            end
        end

        draw_node(connector)
        draw_node_label(connector)
    end

end

function draw_node(connector::ODESystemDesign)
    xo = Observable(0.0)
    yo = Observable(0.0)

    on(connector.xy) do val

        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y

    end

    scatter!(ax[], xo, yo; marker=:rect, color = connector.color, markersize=15)
end

function draw_node_label(connector::ODESystemDesign)
    xo = Observable(0.0)
    yo = Observable(0.0)
    alignment = Observable((:left, :top))

    on(connector.xy) do val

        x = val[1]
        y = val[2]

        xt, yt = get_node_label_position(connector.wall[], x, y)

        xo[] = xt
        yo[] = yt

        alignment[] = get_text_alignment(connector.wall[])
    end

    text!(ax[], xo, yo; text=string(connector.system.name), color = connector.color, align=alignment, fontsize=10)
end

get_node_position(w::Symbol, delta, i) = get_node_position(Val(w), delta, i)
get_node_label_position(w::Symbol, x, y) = get_node_label_position(Val(w), x, y)

get_node_position(::Val{:N}, delta, i) = (delta*i - Δh, +Δh)
get_node_label_position(::Val{:N}, x, y) = (x, y*0.6)

get_node_position(::Val{:S}, delta, i) = (delta*i - Δh, -Δh)
get_node_label_position(::Val{:S}, x, y) = (x, y*0.6)

get_node_position(::Val{:E}, delta, i) = (+Δh, delta*i - Δh)
get_node_label_position(::Val{:E}, x, y) = (x*1.4, y)

get_node_position(::Val{:W}, delta, i) = (-Δh, delta*i - Δh)
get_node_label_position(::Val{:W}, x, y) = (x*1.4, y)


    


function add_system(system::ODESystemDesign)
    
    draw_box(system)
    draw_icon(system)
    draw_label(system)
    draw_nodes(system)

end

function draw_node(connector::ODESystemDesign, delta, i, w, xo, yo)
    if w == :N
        x = delta*i - Δh
        xt = x
        y = +Δh
        yt = y*0.6
    end

    if w == :S
        x = delta*i - Δh
        xt = x
        y = -Δh
        yt = y*0.6
    end

    if w == :E
        x = +Δh
        xt = x*1.4
        y = delta*i - Δh
        yt = y
    end

    if w == :W
        x = -Δh
        xt = x*1.4
        y = delta*i - Δh
        yt = y
    end

    xpo = Observable(0.0)
    on(xo) do val
        xpo[] = val + x
        connector.xy[] = (xpo[], connector.xy[][2])
    end 

    ypo = Observable(0.0)
    on(yo) do val
        ypo[] = val + y
        connector.xy[] = (connector.xy[][1], ypo[])
    end 

    xto = Observable(0.0)
    on(xo) do val
        xto[] = val + xt
    end 

    yto = Observable(0.0)
    on(yo) do val
        yto[] = val + yt
    end 

    

    scatter!(ax[], xpo, ypo; marker=:rect, color = connector.color, markersize=15)
    text!(ax[], xto, yto; text=string(connector.system.name), color = get_color(connector), align=get_text_alignment(w), fontsize=10)
    
end


# box(model::ODESystemDesign, Δh = 0.05) = box(model.xy[][1], model.xy[],[2] Δh)

function box(x, y, Δh = 0.05)   

    xs = [x + Δh, x - Δh, x - Δh, x + Δh, x + Δh]
    ys = [y + Δh, y + Δh, y - Δh, y - Δh, y + Δh]

    return xs, ys
end



end # module ModelingToolkitDesigner
