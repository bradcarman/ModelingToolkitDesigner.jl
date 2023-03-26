using ModelingToolkitDesigner
using ModelingToolkit, OrdinaryDiffEq, Test
using TOML
import ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible as IC
import ModelingToolkitStandardLibrary.Blocks as B
import ModelingToolkitStandardLibrary.Mechanical.Translational as T


using ModelingToolkitDesigner: ODESystemDesign, DesignColorMap, DesignMap



@parameters t
D = Differential(t)

@component function system(N; name)

    pars = []

    systems = @named begin
        fluid = IC.HydraulicFluid()
        stp = B.Step(;height = 10e5, offset = 0, start_time = 0.005, duration = Inf, smooth = 0)
        src = IC.InputSource(;p_int=0)
        vol = IC.FixedVolume(;p_int=0, vol=10.0)
        res = IC.Pipe(N; p_int=0, area=0.01, length=500.0)
    end

    eqs = Equation[]
    
    ODESystem(eqs, t, [], pars; name, systems)
end

@named sys = system(5)


maps = DesignMap[
    DesignColorMap("ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible.HydraulicPort", :blue)
    DesignColorMap("ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible.HydraulicFluid", :blue)
]

function design_file(system::ODESystem)
    @assert !isnothing(system.gui_metadata) "ODESystem must use @component"

    path = joinpath(@__DIR__, "designs")
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

function save_design(design::NamedTuple, system::ODESystem)
    design_dict = Dict()
    for (key, value) in zip(keys(design), values(design))
    
        inner_dict = Dict()
        for (ikey, ivalue) in zip(keys(value), values(value))
            push!(inner_dict, ikey => ivalue)
        end
    
        push!(design_dict, key => inner_dict)
    
    end

    file = design_file(system)

    open(file,"w") do io
        TOML.print(io, design_dict; sorted=true) do val
            if val isa Symbol
                return string(val)
            end
        end
    end

end


res_design = (
    p1 = (x=0.67, y=0.3, port_a=:W),
    p2 = (x=0.84, y=0.3, port_a=:W),
    p3 = (x=1.02, y=0.3, port_a=:W),
    p4 = (x=1.2, y=0.3, port_a=:W),
    v1 = (x=0.58, y=0.46, port=:S),
    v2 = (x=0.76, y=0.46, port=:S),
    v3 = (x=0.93, y=0.46, port=:S),
    v4 = (x=1.12, y=0.46, port=:S),
    v5 = (x=1.3, y=0.46, port=:S),

    port_a = (x=0.54, y=0.14),
    port_b = (x=1.31, y=0.15)
)

save_design(res_design, sys.res)

sys_design = (
    stp = (x=0.0, ),
    src = (x=0.5, input=:W),
    res = (x=1.0, port_a =:W),
    vol = (x=1.5, port=:W),

    fluid = (x=0.5, y=-0.5)
)

save_design(sys_design, sys)

@test ModelingToolkitDesigner.get_color(sys.vol.port, maps) == :blue
@test ModelingToolkitDesigner.get_color(sys.vol, maps) == :black

@test lowercase(abspath(ModelingToolkitDesigner.find_icon(sys.vol))) == lowercase(abspath(raw"icons\ModelingToolkitStandardLibrary\Hydraulic\IsothermalCompressible\FixedVolume.png"))

model = ODESystemDesign(sys, maps, joinpath(@__DIR__, "designs"));

using GLMakie
set_theme!(Theme(fontsize=10))

fig = ModelingToolkitDesigner.view(model)

