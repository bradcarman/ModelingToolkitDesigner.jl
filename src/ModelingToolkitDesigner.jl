module ModelingToolkitDesigner
using GLMakie
using CairoMakie
using ModelingToolkit
using FilterHelpers
using FileIO
using TOML


#TODO: ctrl + up/down/left/right gives bigger jumps




const Δh = 0.05
const dragging = Ref(false)


abstract type DesignMap end

struct DesignColorMap <: DesignMap
    domain::String
    color::Symbol
end

const design_colors = DesignMap[
    DesignColorMap("ModelingToolkitStandardLibrary.Electrical.Pin", :tomato)
    DesignColorMap(
        "ModelingToolkitStandardLibrary.Mechanical.Translational.MechanicalPort",
        :green,
    )
    DesignColorMap(
        "ModelingToolkitStandardLibrary.Mechanical.TranslationalPosition.Flange",
        :green,
    )
    DesignColorMap(
        "ModelingToolkitStandardLibrary.Mechanical.TranslationalPosition.Support",
        :green,
    )
    DesignColorMap("ModelingToolkitStandardLibrary.Mechanical.Rotational.Flange", :green)
    DesignColorMap("ModelingToolkitStandardLibrary.Mechanical.Rotational.Support", :green)
    DesignColorMap("ModelingToolkitStandardLibrary.Thermal.HeatPort", :red)
    DesignColorMap(
        "ModelingToolkitStandardLibrary.Magnetic.FluxTubes.MagneticPort",
        :purple,
    )
    DesignColorMap(
        "ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible.HydraulicPort",
        :blue,
    )
    DesignColorMap(
        "ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible.HydraulicFluid",
        :blue,
    )
]

function add_color(system::ODESystem, color::Symbol)
    @assert ModelingToolkit.isconnector(system) "The `system` must be a connector"

    type = string(system.gui_metadata.type)
    map = DesignColorMap(type, color)
    push!(design_colors, map)

    println("Added $map to `ModelingToolkitDesigner.design_colors`")
end


mutable struct ODESystemDesign
    # parameters::Vector{Parameter}
    # states::Vector{State}

    parent::Union{Symbol,Nothing}
    system::ODESystem
    system_color::Symbol
    components::Vector{ODESystemDesign}
    connectors::Vector{ODESystemDesign}
    connections::Vector{Tuple{ODESystemDesign,ODESystemDesign}}

    xy::Observable{Tuple{Float64,Float64}}
    icon::Union{String,Nothing}
    color::Observable{Symbol}
    wall::Observable{Symbol}

    file::String

end

Base.show(io::IO, x::ODESystemDesign) = print(io, x.system.name)
Base.show(io::IO, x::Tuple{ODESystemDesign,ODESystemDesign}) = print(
    io,
    "$(x[1].parent).$(x[1].system.name) $(round.(x[1].xy[]; digits=2)) <---> $(x[2].parent).$(x[2].system.name) $(round.(x[2].xy[]; digits=2))",
)

Base.copy(x::Tuple{ODESystemDesign,ODESystemDesign}) = (copy(x[1]), copy(x[2]))

Base.copy(x::ODESystemDesign) = ODESystemDesign(
    x.parent,
    x.system,
    x.system_color,
    copy.(x.components),
    copy.(x.connectors),
    copy.(x.connections),
    Observable(x.xy[]),
    x.icon,
    Observable(x.system_color),
    Observable(x.wall[]),
    x.file,
)

function ODESystemDesign(
    system::ODESystem,
    design_path::String;
    x = 0.0,
    y = 0.0,
    icon = nothing,
    wall = :E,
    parent = nothing,
    kwargs...,
)

    file = design_file(system, design_path)
    design_dict = if isfile(file)
        TOML.parsefile(file)
    else
        Dict()
    end

    systems = filter(x -> typeof(x) == ODESystem, ModelingToolkit.get_systems(system))

    components = ODESystemDesign[]
    connectors = ODESystemDesign[]
    connections = Tuple{ODESystemDesign,ODESystemDesign}[]


    if !isempty(systems)

        process_children!(
            components,
            systems,
            design_dict,
            design_path,
            system.name,
            false;
            kwargs...,
        )
        process_children!(
            connectors,
            systems,
            design_dict,
            design_path,
            system.name,
            true;
            kwargs...,
        )


        for eq in equations(system)

            if eq.rhs isa Connection

                conns = []
                for connector in eq.rhs.systems
                    if contains(string(connector.name), '₊')
                        # connector of child system
                        conn_parent, child = split(string(connector.name), '₊')
                        child_design = filtersingle(
                            x -> string(x.system.name) == conn_parent,
                            components,
                        )
                        if !isnothing(child_design)
                            connector_design = filtersingle(
                                x -> string(x.system.name) == child,
                                child_design.connectors,
                            )
                        else
                            connector_design = nothing
                        end
                    else
                        # connector of parent system
                        connector_design =
                            filtersingle(x -> x.system.name == connector.name, connectors)
                    end

                    if !isnothing(connector_design)
                        push!(conns, connector_design)
                    end
                end

                for i = 2:length(conns)
                    push!(connections, (conns[i-1], conns[i]))
                end


            end


        end

    end



    xy = Observable((x, y))
    color = get_color(system)
    if wall isa String
        wall = Symbol(wall)
    end

    return ODESystemDesign(
        parent,
        system,
        color,
        components,
        connectors,
        connections,
        xy,
        icon,
        Observable(color),
        Observable(wall),
        file,
    )
end

is_pass_thru(design::ODESystemDesign) = is_pass_thru(design.system)
function is_pass_thru(system::ODESystem)
    types = split(string(system.gui_metadata.type), '.')

    component_type = types[end]

    return startswith(component_type, "PassThru")
end

function design_file(system::ODESystem, path::String)
    @assert !isnothing(system.gui_metadata) "ODESystem must use @component"

    # path = joinpath(@__DIR__, "designs")
    if !isdir(path)
        mkdir(path)
    end

    parts = split(string(system.gui_metadata.type), '.')
    for part in parts[1:end-1]
        path = joinpath(path, part)
        if !isdir(path)
            mkdir(path)
        end
    end
    file = joinpath(path, "$(parts[end]).toml")

    return file
end

function process_children!(
    children::Vector{ODESystemDesign},
    systems::Vector{ODESystem},
    design_dict::Dict,
    design_path::String,
    parent::Symbol,
    is_connector = false;
    connectors...,
)
    systems = filter(x -> ModelingToolkit.isconnector(x) == is_connector, systems)
    if !isempty(systems)
        for (i, system) in enumerate(systems)
            # key = Symbol(namespace, "₊", system.name)
            key = string(system.name)
            kwargs = if haskey(design_dict, key)
                design_dict[key]
            else
                Dict()
            end

            kwargs_pair = Pair[]


            push!(kwargs_pair, :parent => parent)


            if !is_connector
                if !haskey(kwargs, "x") & !haskey(kwargs, "y")
                    push!(kwargs_pair, :x => i * 3 * Δh)
                    push!(kwargs_pair, :y => i * Δh)
                end
            else
                if haskey(connectors, system.name)
                    push!(kwargs_pair, :wall => connectors[system.name])
                end
            end

            for (key, value) in kwargs
                push!(kwargs_pair, Symbol(key) => value)
            end
            push!(kwargs_pair, :icon => find_icon(system, design_path))

            push!(
                children,
                ODESystemDesign(system, design_path; NamedTuple(kwargs_pair)...),
            )
        end

    end

end

function get_design_path(design::ODESystemDesign)
    type = string(design.system.gui_metadata.type)
    parts = split(type, '.')
    path = joinpath(parts[1:end-1]..., "$(parts[end]).toml")
    return replace(design.file, path => "")
end

find_icon(design::ODESystemDesign) = find_icon(design.system, get_design_path(design))

function find_icon(system::ODESystem, design_path::String)
    type = string(system.gui_metadata.type)
    path = split(type, '.')

    bases = [
        design_path
        joinpath(@__DIR__, "..", "icons")
    ]

    icons = [joinpath(base, path[1:end-1]..., "$(path[end]).png") for base in bases]

    for icon in icons
        isfile(icon) && return icon
    end

    return joinpath(bases[end], "NotFound.png")
end


function is_tuple_approx(a::Tuple{Float64,Float64}, b::Tuple{Float64,Float64}; atol)

    r1 = isapprox(a[1], b[1]; atol)
    r2 = isapprox(a[2], b[2]; atol)

    return all([r1, r2])
end

get_change(::Val) = (0.0, 0.0)
get_change(::Val{Keyboard.up}) = (0.0, +Δh / 5)
get_change(::Val{Keyboard.down}) = (0.0, -Δh / 5)
get_change(::Val{Keyboard.left}) = (-Δh / 5, 0.0)
get_change(::Val{Keyboard.right}) = (+Δh / 5, 0.0)



function view(design::ODESystemDesign, interactive = true)

    if interactive
        GLMakie.activate!()
    else
        CairoMakie.activate!()
    end



    fig = Figure()

    title = if isnothing(design.parent)
        "$(design.system.name) [$(design.file)]"
    else
        "$(design.parent).$(design.system.name) [$(design.file)]"
    end

    ax = Axis(
        fig[2:11, 1:10];
        aspect = DataAspect(),
        yticksvisible = false,
        xticksvisible = false,
        yticklabelsvisible = false,
        xticklabelsvisible = false,
        xgridvisible = false,
        ygridvisible = false,
        bottomspinecolor = :transparent,
        leftspinecolor = :transparent,
        rightspinecolor = :transparent,
        topspinecolor = :transparent,
    )

    if interactive
        connect_button = Button(fig[12, 1]; label = "connect", fontsize = 12)
        clear_selection_button =
            Button(fig[12, 2]; label = "clear selection", fontsize = 12)
        next_wall_button = Button(fig[12, 3]; label = "move node", fontsize = 12)
        align_horrizontal_button = Button(fig[12, 4]; label = "align horz.", fontsize = 12)
        align_vertical_button = Button(fig[12, 5]; label = "align vert.", fontsize = 12)
        open_button = Button(fig[12, 6]; label = "open", fontsize = 12)
        mode_toggle = Toggle(fig[12, 7])

        save_button = Button(fig[12, 10]; label = "save", fontsize = 12)


        Label(fig[1, :], title; halign = :left, fontsize = 11)
    end

    for component in design.components
        add_component!(ax, component)
        for connector in component.connectors
            notify(connector.wall)
        end
        notify(component.xy)
    end

    for connector in design.connectors
        add_component!(ax, connector)
        notify(connector.xy)
    end

    for connection in design.connections
        connect!(ax, connection)
    end

    if interactive
        on(events(fig).mousebutton, priority = 2) do event

            if event.button == Mouse.left
                if event.action == Mouse.press

                    # if Keyboard.s in events(fig).keyboardstate
                    # Delete marker
                    plt, i = pick(fig)

                    if !isnothing(plt)

                        if plt isa Image

                            image = plt
                            xobservable = image[1]
                            xvalues = xobservable[]
                            yobservable = image[2]
                            yvalues = yobservable[]


                            x = xvalues[1] + Δh * 0.8
                            y = yvalues[1] + Δh * 0.8
                            selected_system = filtersingle(
                                s -> is_tuple_approx(s.xy[], (x, y); atol = 1e-3),
                                [design.components; design.connectors],
                            )

                            if isnothing(selected_system)

                                x = xvalues[1] + Δh * 0.8 * 0.5
                                y = yvalues[1] + Δh * 0.8 * 0.5
                                selected_system = filtersingle(
                                    s -> is_tuple_approx(s.xy[], (x, y); atol = 1e-3),
                                    [design.components; design.connectors],
                                )

                                if isnothing(selected_system)
                                    @warn "clicked an image at ($(round(x; digits=1)), $(round(y; digits=1))), but no system design found!"
                                else
                                    selected_system.color[] = :pink
                                    dragging[] = true
                                end
                            else
                                selected_system.color[] = :pink
                                dragging[] = true
                            end



                        elseif plt isa Lines

                        elseif plt isa Scatter

                            point = plt
                            observable = point[1]
                            values = observable[]
                            geometry_point = Float64.(values[1])

                            x = geometry_point[1]
                            y = geometry_point[2]

                            selected_component = filtersingle(
                                c -> is_tuple_approx(c.xy[], (x, y); atol = 1e-3),
                                design.components,
                            )
                            if !isnothing(selected_component)
                                selected_component.color[] = :pink
                            else
                                all_connectors =
                                    vcat([s.connectors for s in design.components]...)
                                selected_connector = filtersingle(
                                    c -> is_tuple_approx(c.xy[], (x, y); atol = 1e-3),
                                    all_connectors,
                                )
                                selected_connector.color[] = :pink
                            end

                        elseif plt isa Mesh



                        end


                    end
                    Consume(true)
                elseif event.action == Mouse.release

                    dragging[] = false
                    Consume(true)
                end
            end

            if event.button == Mouse.right
                clear_selection(design)
                Consume(true)
            end

            return Consume(false)
        end

        on(events(fig).mouseposition, priority = 2) do mp
            if dragging[]
                for sub_design in [design.components; design.connectors]
                    if sub_design.color[] == :pink
                        position = mouseposition(ax)
                        sub_design.xy[] = (position[1], position[2])
                        break #only move one system for mouse drag
                    end
                end

                return Consume(true)
            end

            return Consume(false)
        end

        on(events(fig).keyboardbutton) do event
            if event.action == Keyboard.press

                change = get_change(Val(event.key))

                if change != (0.0, 0.0)
                    for sub_design in [design.components; design.connectors]
                        if sub_design.color[] == :pink

                            xc = sub_design.xy[][1]
                            yc = sub_design.xy[][2]

                            sub_design.xy[] = (xc + change[1], yc + change[2])

                        end
                    end

                    reset_limits!(ax)

                    return Consume(true)
                end
            end
        end

        on(connect_button.clicks) do clicks
            connect!(ax, design)
        end

        on(clear_selection_button.clicks) do clicks
            clear_selection(design)
        end

        on(next_wall_button.clicks) do clicks
            for component in design.components
                for connector in component.connectors
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

        on(align_horrizontal_button.clicks) do clicks
            align(design, :horrizontal)
        end

        on(align_vertical_button.clicks) do clicks
            align(design, :vertical)
        end

        on(open_button.clicks) do clicks
            for component in design.components
                if component.color[] == :pink
                    view_design =
                        ODESystemDesign(component.system, get_design_path(component))
                    view_design.parent = design.system.name
                    fig_ = view(view_design)
                    display(GLMakie.Screen(), fig_)
                    break
                end
            end
        end

        on(save_button.clicks) do clicks
            save_design(design)
        end

        on(mode_toggle.active) do val
            toggle_pass_thrus(design, val)
        end
    end

    toggle_pass_thrus(design, !interactive)

    return fig
end

function toggle_pass_thrus(design::ODESystemDesign, hide::Bool)
    for component in design.components
        if is_pass_thru(component)
            if hide
                component.color[] = :transparent
                for connector in component.connectors
                    connector.color[] = :transparent
                end
            else
                component.color[] = component.system_color
                for connector in component.connectors
                    connector.color[] = connector.system_color
                end
            end
        else

        end
    end
end

function align(design::ODESystemDesign, type)
    xs = Float64[]
    ys = Float64[]
    for sub_design in [design.components; design.connectors]
        if sub_design.color[] == :pink
            x, y = sub_design.xy[]
            push!(xs, x)
            push!(ys, y)
        end
    end

    ym = sum(ys) / length(ys)
    xm = sum(xs) / length(xs)

    for sub_design in [design.components; design.connectors]
        if sub_design.color[] == :pink

            x, y = sub_design.xy[]

            if type == :horrizontal
                sub_design.xy[] = (x, ym)
            elseif type == :vertical
                sub_design.xy[] = (xm, y)
            end


        end
    end
end

function clear_selection(design::ODESystemDesign)
    for component in design.components
        for connector in component.connectors
            connector.color[] = connector.system_color
        end
        component.color[] = :black
    end
    for connector in design.connectors
        connector.color[] = connector.system_color
    end
end

function connect!(ax::Axis, design::ODESystemDesign)
    all_connectors = vcat([s.connectors for s in design.components]...)
    push!(all_connectors, design.connectors...)
    selected_connectors = ODESystemDesign[]

    for connector in all_connectors
        if connector.color[] == :pink
            push!(selected_connectors, connector)
            connector.color[] = connector.system_color
        end
    end

    if length(selected_connectors) > 1
        connect!(ax, (selected_connectors[1], selected_connectors[2]))
        push!(design.connections, (selected_connectors[1], selected_connectors[2]))
    end
end

function connect!(ax::Axis, connection::Tuple{ODESystemDesign,ODESystemDesign})

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

    lines!(ax, xs, ys; color = connection[1].color[], linestyle = style)
end

get_wall(design::ODESystemDesign) = design.wall[]

get_text_alignment(wall::Symbol) = get_text_alignment(Val(wall))
get_text_alignment(::Val{:E}) = (:left, :top)
get_text_alignment(::Val{:W}) = (:right, :top)
get_text_alignment(::Val{:S}) = (:left, :top)
get_text_alignment(::Val{:N}) = (:left, :bottom)

get_color(design::ODESystemDesign) = get_color(design.system)
function get_color(system::ODESystem)
    if !isnothing(system.gui_metadata)
        domain = string(system.gui_metadata.type)
        # domain_parts = split(full_domain, '.')
        # domain = join(domain_parts[1:end-1], '.')

        map = filtersingle(
            x -> (x.domain == domain) & (typeof(x) == DesignColorMap),
            design_colors,
        )

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

function draw_box!(ax::Axis, design::ODESystemDesign)

    xo = Observable(zeros(5))
    yo = Observable(zeros(5))


    Δh_, linewidth = if ModelingToolkit.isconnector(design.system)
        0.6 * Δh, 2
    else
        Δh, 1
    end

    on(design.xy) do val
        x = val[1]
        y = val[2]

        xo[], yo[] = box(x, y, Δh_)
    end


    lines!(ax, xo, yo; color = design.color, linewidth)


    if !isempty(design.components)
        xo2 = Observable(zeros(5))
        yo2 = Observable(zeros(5))

        on(design.xy) do val
            x = val[1]
            y = val[2]

            xo2[], yo2[] = box(x, y, Δh_ * 1.1)
        end


        lines!(ax, xo2, yo2; color = design.color, linewidth)
    end


end


function draw_passthru!(ax::Axis, design::ODESystemDesign)

    xo = Observable(0.0)
    yo = Observable(0.0)

    on(design.xy) do val
        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y
    end

    scatter!(ax, xo, yo; color = first(design.connectors).system_color, marker = :circle)

    for connector in design.connectors
        cxo = Observable(zeros(2))
        cyo = Observable(zeros(2))

        function update()
            cxo[] = [connector.xy[][1], design.xy[][1]]
            cyo[] = [connector.xy[][2], design.xy[][2]]
        end

        on(connector.xy) do val
            update()
        end

        on(design.xy) do val
            update()
        end

        lines!(ax, cxo, cyo; color = connector.system_color)
    end

end

function draw_icon!(ax::Axis, design::ODESystemDesign)

    xo = Observable(zeros(2))
    yo = Observable(zeros(2))

    scale = if ModelingToolkit.isconnector(design.system)
        0.5 * 0.8
    else
        0.8
    end

    on(design.xy) do val

        x = val[1]
        y = val[2]

        xo[] = [x - Δh * scale, x + Δh * scale]
        yo[] = [y - Δh * scale, y + Δh * scale]

    end


    if !isnothing(design.icon)
        img = load(design.icon)
        image!(ax, xo, yo, rotr90(img))
    end
end

function draw_label!(ax::Axis, design::ODESystemDesign)

    xo = Observable(0.0)
    yo = Observable(0.0)

    scale = if ModelingToolkit.isconnector(design.system)
        1 + 0.75 * 0.5
    else
        0.925
    end

    on(design.xy) do val

        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y - Δh * scale

    end

    text!(ax, xo, yo; text = string(design.system.name), align = (:center, :bottom))
end

function draw_nodes!(ax::Axis, design::ODESystemDesign)

    xo = Observable(0.0)
    yo = Observable(0.0)

    on(design.xy) do val

        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y

    end

    update =
        (connector) -> begin

            connectors_on_wall =
                filter(x -> x.wall[] == connector.wall[], design.connectors)

            n_items = length(connectors_on_wall)
            delta = 2 * Δh / (n_items + 1)

            for i = 1:n_items
                x, y = get_node_position(connector.wall[], delta, i)
                connectors_on_wall[i].xy[] = (x + xo[], y + yo[])
            end
        end


    for connector in design.connectors

        on(connector.wall) do val
            update(connector)
        end

        on(design.xy) do val
            update(connector)
        end

        draw_node!(ax, connector)
        draw_node_label!(ax, connector)
    end

end

function draw_node!(ax::Axis, connector::ODESystemDesign)
    xo = Observable(0.0)
    yo = Observable(0.0)

    on(connector.xy) do val

        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y

    end

    scatter!(ax, xo, yo; marker = :rect, color = connector.color, markersize = 15)
end

function draw_node_label!(ax::Axis, connector::ODESystemDesign)
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

    scene = GLMakie.Makie.parent_scene(ax)
    current_font_size = theme(scene, :fontsize)

    text!(
        ax,
        xo,
        yo;
        text = string(connector.system.name),
        color = connector.color,
        align = alignment,
        fontsize = current_font_size[] * 0.625,
    )
end

get_node_position(w::Symbol, delta, i) = get_node_position(Val(w), delta, i)
get_node_label_position(w::Symbol, x, y) = get_node_label_position(Val(w), x, y)

get_node_position(::Val{:N}, delta, i) = (delta * i - Δh, +Δh)
get_node_label_position(::Val{:N}, x, y) = (x + Δh / 10, y + Δh / 5)

get_node_position(::Val{:S}, delta, i) = (delta * i - Δh, -Δh)
get_node_label_position(::Val{:S}, x, y) = (x + Δh / 10, y - Δh / 5)

get_node_position(::Val{:E}, delta, i) = (+Δh, delta * i - Δh)
get_node_label_position(::Val{:E}, x, y) = (x + Δh / 5, y)

get_node_position(::Val{:W}, delta, i) = (-Δh, delta * i - Δh)
get_node_label_position(::Val{:W}, x, y) = (x - Δh / 5, y)





function add_component!(ax::Axis, design::ODESystemDesign)

    draw_box!(ax, design)
    draw_nodes!(ax, design)

    if is_pass_thru(design)
        draw_passthru!(ax, design)
    else
        draw_icon!(ax, design)
        draw_label!(ax, design)
    end

end

# box(model::ODESystemDesign, Δh = 0.05) = box(model.xy[][1], model.xy[],[2] Δh)

function box(x, y, Δh = 0.05)

    xs = [x + Δh, x - Δh, x - Δh, x + Δh, x + Δh]
    ys = [y + Δh, y + Δh, y - Δh, y - Δh, y + Δh]

    return xs, ys
end


# function get_design_code(design::ODESystemDesign)
#     println("[")
#     for child_design in design.systems
#         println("\t$(design.system.name).$(child_design.system.name) => (x=$(round(child_design.xy[][1]; digits=2)), y=$(round(child_design.xy[][2]; digits=2)))")
#         for node in child_design.connectors
#             if node.wall[] != :E
#                 println("\t$(design.system.name).$(child_design.system.name).$(node.system.name) => (wall=:$(node.wall[]),)")
#             end
#         end
#     end
#     println()
#     for node in design.connectors
#         println("\t$(design.system.name).$(node.system.name) => (x=$(round(node.xy[][1]; digits=2)), y=$(round(node.xy[][2]; digits=2)))")
#     end
#     println("]")
# end

function connection_part(design::ODESystemDesign, connection::ODESystemDesign)
    if connection.parent == design.system.name
        return "$(connection.system.name)"
    else
        return "$(connection.parent).$(connection.system.name)"
    end
end

connection_code(design::ODESystemDesign) = connection_code(stdout, design)
function connection_code(io::IO, design::ODESystemDesign)

    for connection in design.connections
        println(
            io,
            "connect($(connection_part(design, connection[1])), $(connection_part(design, connection[2])))",
        )
    end

end

function save_design(design::ODESystemDesign)


    design_dict = Dict()

    for component in design.components

        x, y = component.xy[]

        pairs = Pair{Symbol,Any}[
            :x => round(x; digits = 2)
            :y => round(y; digits = 2)
        ]

        for connector in component.connectors
            if connector.wall[] != :E
                push!(pairs, connector.system.name => string(connector.wall[]))
            end
        end

        design_dict[component.system.name] = Dict(pairs)
    end

    for connector in design.connectors
        x, y = connector.xy[]

        pairs = Pair{Symbol,Any}[
            :x => round(x; digits = 2)
            :y => round(y; digits = 2)
        ]

        design_dict[connector.system.name] = Dict(pairs)
    end

    save_design(design_dict, design.file)

    connection_file = replace(design.file, ".toml" => ".jl")
    open(connection_file, "w") do io
        connection_code(io, design)
    end
end

function save_design(design_dict::Dict, file::String)
    open(file, "w") do io
        TOML.print(io, design_dict; sorted = true) do val
            if val isa Symbol
                return string(val)
            end
        end
    end
end

# macro input(file)
#     s = if isfile(file)
#         read(file, String)
#     else
#         ""
#     end
#     e = Meta.parse(s)
#     esc(e)
# end

export ODESystemDesign, DesignColorMap, connection_code, add_color


end # module ModelingToolkitDesigner
