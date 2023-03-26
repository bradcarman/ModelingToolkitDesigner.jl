module ModelingToolkitDesigner
using GLMakie
using ModelingToolkit
using FilterHelpers
using FileIO
using TOML


#TODO: write out design code

#TODO: click and drag systems
#TODO: ctrl + up/down/left/right gives bigger jumps
#TODO: align selected components

#TODO: draw connector types as smaller boxes with bolder boarders
#TODO: add connections to connector children
#TODO: add PipeBase and HydraulicPort icons

const ax = Ref{Axis}()
const Δh = 0.05

abstract type DesignMap end

struct DesignColorMap <: DesignMap
    domain::String
    color::Symbol
end

struct DesignStyleMap <: DesignMap
    domain::String
    style::Symbol
end

mutable struct ODESystemDesign
    # parameters::Vector{Parameter}
    # states::Vector{State}
    
    system::ODESystem
    system_color::Symbol
    systems::Vector{ODESystemDesign}
    connectors::Vector{ODESystemDesign}
    connections::Vector{Tuple{ODESystemDesign, ODESystemDesign}}
    
    xy::Observable{Tuple{Float64, Float64}}
    icon::Union{String, Nothing}
    color::Observable{Symbol}
    wall::Observable{Symbol}

end

function design_file(system::ODESystem, path::String)
    @assert !isnothing(system.gui_metadata) "ODESystem must use @component"

    # path = joinpath(@__DIR__, "designs")
    if !isdir(path)
        mkdir(path)
    end

    parts = split(string(system.gui_metadata.type),'.')
    for part in parts[1:end-1]
        path = joinpath(path, part)
        if !isdir(path)
            mkdir(path)
        end
    end
    file = joinpath(path, "$(parts[end]).toml")

    return file
end

function process_children!(children::Vector{ODESystemDesign}, systems::Vector{ODESystem}, design::Dict, maps, design_path, is_connector=false; connectors...)
    children_ = filter(x->ModelingToolkit.isconnector(x) == is_connector, systems)
    if !isempty(children_)
        for (i,c) in enumerate(children_)
            # key = Symbol(namespace, "₊", c.name)
            key = string(c.name)
            kwargs = if haskey(design, key)
                design[key]
            else
                Dict()
            end
    
            kwargs_pair = Pair[]
    
            if !is_connector
                if !haskey(kwargs, :x) && !haskey(kwargs, :y)
                    push!(kwargs_pair, :x=> i*3*Δh )
                    push!(kwargs_pair, :y=> i*Δh )
                end
            else
                if haskey(connectors, c.name)
                    push!(kwargs_pair, :wall => connectors[c.name])
                end
            end
    
            for (key, value) in kwargs
                push!(kwargs_pair, Symbol(key)=>value)
            end
            push!(kwargs_pair, :icon=>find_icon(c))
    
            push!(children, ODESystemDesign(c, maps, design_path; NamedTuple(kwargs_pair)...))                
        end
       
    end
    
end

function ODESystemDesign(system::ODESystem, maps::Vector{DesignMap}, design_path::String; x=0.0, y=0.0, icon=nothing, wall=:E, kwargs...)

    file = design_file(system, design_path)
    design = if isfile(file)
        TOML.parsefile(file)
    else
        Dict()
    end

    println("system: $(system.name)")
    # if !isnothing(rootnamespace)
    #     namespace = Symbol(rootnamespace, "₊", system.name)
    # else
    #     namespace = system.name
    # end

    systems = filter(x-> typeof(x) == ODESystem, ModelingToolkit.get_systems(system))
    

    children = ODESystemDesign[]
    connectors = ODESystemDesign[]
    connections = Tuple{ODESystemDesign, ODESystemDesign}[]
    if !isempty(systems)
        
        process_children!(children, systems, design, maps, design_path, false; kwargs...)
        process_children!(connectors, systems, design, maps, design_path, true; kwargs...)
        
        for eq in equations(system)

            if eq.rhs isa Connection

                
                conns = []
                for connector in eq.rhs.systems

                    if contains(string(connector.name), '₊')
                        parent, child = split(string(connector.name), '₊')                   

                        
                        child_design = filtersingle(x->string(x.system.name) == parent, children)

                        if !isnothing(child_design)
                            connector_design = filtersingle(x->string(x.system.name) == child, child_design.connectors)
                            push!(conns, connector_design)
                        end
                    end
                end

                for i=2:length(conns)
                    push!(connections, (conns[i-1], conns[i]))
                end


            end


        end
   
    end

    xy= Observable((x,y))
    color = get_color(system, maps) 
    if wall isa String
        wall = Symbol(wall)
    end


    return ODESystemDesign(system, color, children, connectors, connections, xy, icon, Observable(color), Observable(wall))
end

function find_icon(sys::ODESystem)
    type = string(sys.gui_metadata.type)

    path = split(type, '.')

    base = joinpath(@__DIR__, "..", "icons")

    icon = joinpath(base, path[1:end-1]..., "$(path[end]).png")

    if isfile(icon)
        return icon
    else
        return joinpath(base, "NotFound.png")
    end   

end

 
function Base.isapprox(a::Tuple{Float64, Float64}, b::Tuple{Float64, Float64}; atol)

    r1 = isapprox(a[1], b[1]; atol)
    r2 = isapprox(a[2], b[2]; atol)

    return all([r1, r2])
end

get_change(::Val) = (0.0, 0.0)
get_change(::Val{Keyboard.up}) = (0.0, +Δh/5)
get_change(::Val{Keyboard.down}) = (0.0, -Δh/5)
get_change(::Val{Keyboard.left}) = (-Δh/5, 0.0)
get_change(::Val{Keyboard.right}) = (+Δh/5, 0.0)

function view(model::ODESystemDesign)

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
        for connector in system.connectors
            notify(connector.wall)
        end
        notify(system.xy)
    end

    for connector in model.connectors
        add_system(connector)
        notify(connector.xy)
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


                        x = xvalues[1] + Δh*0.8
                        y = yvalues[1] + Δh*0.8


                        selected_system = filtersingle(s->isapprox(s.xy[], (x,y); atol=1e-3), [model.systems; model.connectors])

                        if isnothing(selected_system)
                            @warn "clicked an image at ($(round(x; digits=1)), $(round(y; digits=1))), but no system design found!" 
                        else
                            selected_system.color[] = :pink
                        end

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
                connector.color[] = connector.system_color
            end
            system.color[] = :black
        end
        for connector in model.connectors
            connector.color[] = connector.system_color
        end
    end

    on(events(fig).keyboardbutton) do event
        if event.action == Keyboard.press
            change = get_change(Val(event.key))
            
            if change != (0.0, 0.0)
                for system in [model.systems; model.connectors]
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

    return fig
end



function connect(model::ODESystemDesign)



    all_connectors = vcat([s.connectors for s in model.systems]...)

    push!(all_connectors, model.connectors...)

    selected_connectors = ODESystemDesign[]



    local color
    for connector in all_connectors
        if connector.color[] == :pink
            push!(selected_connectors, connector)
            connector.color[] = connector.system_color
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

    style = :solid
    for connector in connection
        s = get_style(connector)
        if s != :solid
            style = s
        end

        on(connector.xy) do val
            update()
        end
    end

    update()  

    lines!(ax[], xs, ys; color=connection[1].color[], linestyle=style)
end





get_wall(system::ODESystemDesign) = system.wall[]


get_text_alignment(wall::Symbol) = get_text_alignment(Val(wall))
get_text_alignment(::Val{:E}) = (:left, :top)
get_text_alignment(::Val{:W}) = (:right, :top)
get_text_alignment(::Val{:S}) = (:left, :top)
get_text_alignment(::Val{:N}) = (:right, :bottom)


get_color(system_design::ODESystemDesign, maps::Vector{DesignMap}) = get_color(system_design.system, maps)
function get_color(system::ODESystem, maps::Vector{DesignMap})
    if !isnothing(system.gui_metadata)
        domain = string(system.gui_metadata.type)
        # domain_parts = split(full_domain, '.')
        # domain = join(domain_parts[1:end-1], '.')

        map = filtersingle(x->(x.domain == domain) & (typeof(x) == DesignColorMap), maps)

        if !isnothing(map)
            return map.color
        end
    end

    return :black
end

get_style(design::ODESystemDesign) = get_style(design.system)
function get_style(system::ODESystem)

    sts = ModelingToolkit.get_states(system)
    if length(sts) == 1
        s = first(sts)
        vtype = ModelingToolkit.get_connection_type(s)
        if vtype === ModelingToolkit.Flow
            return :dash
        end
    end

    return :solid
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

        scale = 0.8

        xo[] = [x - Δh*scale, x + Δh*scale]
        yo[] = [y - Δh*scale, y + Δh*scale]

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
        yo[] = y - Δh*1.75

    end

    text!(ax[], xo, yo; text=string(system.system.name), align=(:center, :bottom))
end

function draw_nodes(system::ODESystemDesign)
  
    xo = Observable(0.0)
    yo = Observable(0.0)

    on(system.xy) do val

        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y

    end

    update = (connector) -> begin
        println("updating node: $(system.system.name) $(connector.system.name)")
        connectors_on_wall = filter(x->x.wall[] == connector.wall[], system.connectors)

        n_items = length(connectors_on_wall)
        delta = 2*Δh/(n_items+1)

        for i=1:n_items
            x,y = get_node_position(connector.wall[], delta, i)
            connectors_on_wall[i].xy[] = (x+xo[],y+yo[])
        end
    end


    for connector in system.connectors

        on(connector.wall) do val
            update(connector)
        end

        on(system.xy) do val
            update(connector)
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

    scene = GLMakie.Makie.parent_scene(ax[])
    current_font_size = theme(scene, :fontsize)

    text!(ax[], xo, yo; text=string(connector.system.name), color = connector.color, align=alignment, fontsize=current_font_size[]*0.625)
end

get_node_position(w::Symbol, delta, i) = get_node_position(Val(w), delta, i)
get_node_label_position(w::Symbol, x, y) = get_node_label_position(Val(w), x, y)

get_node_position(::Val{:N}, delta, i) = (delta*i - Δh, +Δh)
get_node_label_position(::Val{:N}, x, y) = (x, y+Δh/5)

get_node_position(::Val{:S}, delta, i) = (delta*i - Δh, -Δh)
get_node_label_position(::Val{:S}, x, y) = (x, y-Δh/5)

get_node_position(::Val{:E}, delta, i) = (+Δh, delta*i - Δh)
get_node_label_position(::Val{:E}, x, y) = (x+Δh/5, y)

get_node_position(::Val{:W}, delta, i) = (-Δh, delta*i - Δh)
get_node_label_position(::Val{:W}, x, y) = (x-Δh/5, y)


    


function add_system(system::ODESystemDesign)
    
    draw_box(system)
    draw_icon(system)
    draw_label(system)
    draw_nodes(system)

end

# box(model::ODESystemDesign, Δh = 0.05) = box(model.xy[][1], model.xy[],[2] Δh)

function box(x, y, Δh = 0.05)   

    xs = [x + Δh, x - Δh, x - Δh, x + Δh, x + Δh]
    ys = [y + Δh, y + Δh, y - Δh, y - Δh, y + Δh]

    return xs, ys
end


function get_design_code(design::ODESystemDesign)
    println("[")
    for child_design in design.systems
        println("\t$(design.system.name).$(child_design.system.name) => (x=$(round(child_design.xy[][1]; digits=2)), y=$(round(child_design.xy[][2]; digits=2)))")
        for node in child_design.connectors
            if node.wall[] != :E
                println("\t$(design.system.name).$(child_design.system.name).$(node.system.name) => (wall=:$(node.wall[]),)")
            end
        end
    end
    println()
    for node in design.connectors
        println("\t$(design.system.name).$(node.system.name) => (x=$(round(node.xy[][1]; digits=2)), y=$(round(node.xy[][2]; digits=2)))")
    end
    println("]")
end


end # module ModelingToolkitDesigner
