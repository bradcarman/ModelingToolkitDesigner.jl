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
    wall::Symbol
end

function ODESystemDesign(rootnamespace::Union{Symbol, Nothing}, system::ODESystem, design::Dict; x=0.0, y=0.0, icon=nothing, wall=:E)

    println("system: $(system.name)")
    if !isnothing(rootnamespace)
        namespace = Symbol(rootnamespace, "₊", system.name)
    else
        namespace = system.name
    end

    systems = filter(x-> typeof(x) == ODESystem, ModelingToolkit.get_systems(system))
    

    children = ODESystemDesign[]
    connectors = ODESystemDesign[]
    connections = Pair[]
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

                connections = ODESystemDesign[]
                for connector in eq.rhs.systems

                    parent, child = split(string(connector.name), '₊')                   
                    child_design = filtersingle(x->string(x.system.name) == parent, children)
                    connector_design = filtersingle(x->string(x.system.name) == child, child_design.connectors)

                    push!(connections, connector_design)
                end


            end


        end
        
        
    
    end

    xy= Observable((x,y))



    return ODESystemDesign(rootnamespace, system, children, connectors, connections, Equation[], xy, icon, Observable(get_color(system)), wall)
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
                    Main._x[] = plt

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


    fig

end



function connect(model::ODESystemDesign)



    all_connectors = vcat([s.connectors for s in model.systems]...)

    selected_connectors = ODESystemDesign[]



    local color
    for connector in all_connectors

        if connector.color[] == :pink

            
            push!(selected_connectors, connector)
       
            on(connector.xy) do val
                update()
            end

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


    update()  


    lines!(ax[], xs, ys; color=connection[1].color)
end





get_wall(system::ODESystemDesign) = system.wall


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


function add_system(system::ODESystemDesign)
    Δh = 0.05

    xso = Observable(zeros(5))
    yso = Observable(zeros(5))

    xo = Observable(0.0)
    yo = Observable(0.0)

    xro = Observable(zeros(2))
    yro = Observable(zeros(2))

    on(system.xy) do val
        xs, ys = box(val[1], val[2])
        xso[] = xs
        yso[] = ys

        xro[] = [minimum(xs), maximum(xs)]
        yro[] = [minimum(ys), maximum(ys)]

        xo[] = val[1]
        yo[] = val[2]
    end

    lines!(ax[], xso, yso; color=system.color)

    if !isnothing(system.icon)
        img = load(system.icon)       
        image!(ax[], xro, yro, rotr90(img))
    end    

    ylabelo = Observable(0.0)
    on(yo) do val
        ylabelo[] = val - 0.1
    end

    text!(ax[], xo, ylabelo; text=string(system.system.name), align=(:center, :bottom))

    wall(y) = filter(x->get_wall(x) == y, system.connectors)

    # walls = [ModelingToolkitComponents.N, ModelingToolkitComponents.S, ModelingToolkitComponents.E, ModelingToolkitComponents.W]
    walls = [:N, :S, :E, :W]
    for w in walls


        connectors_on_wall = wall(w)

        n_items = length(connectors_on_wall)
        delta = 2*Δh/(n_items+1)

        #TODO: Order by item.node_order

        for i=1:n_items

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
                connectors_on_wall[i].xy[] = (xpo[], connectors_on_wall[i].xy[][2])
            end 

            ypo = Observable(0.0)
            on(yo) do val
                ypo[] = val + y
                connectors_on_wall[i].xy[] = (connectors_on_wall[i].xy[][1], ypo[])
            end 

            xto = Observable(0.0)
            on(xo) do val
                xto[] = val + xt
            end 

            yto = Observable(0.0)
            on(yo) do val
                yto[] = val + yt
            end 

            

            scatter!(ax[], xpo, ypo; marker=:rect, color = connectors_on_wall[i].color, markersize=15)
            text!(ax[], xto, yto; text=string(connectors_on_wall[i].system.name), color = get_color(connectors_on_wall[i]), align=get_text_alignment(w), fontsize=10)
            
        end


    end

end


# box(model::ODESystemDesign, Δh = 0.05) = box(model.xy[][1], model.xy[],[2] Δh)

function box(x, y, Δh = 0.05)   

    xs = [x + Δh, x - Δh, x - Δh, x + Δh, x + Δh]
    ys = [y + Δh, y + Δh, y - Δh, y - Δh, y + Δh]

    return xs, ys
end



end # module ModelingToolkitDesigner
