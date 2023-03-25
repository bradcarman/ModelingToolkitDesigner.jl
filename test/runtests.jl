using ModelingToolkitDesigner
using ModelingToolkit, OrdinaryDiffEq, Test
import ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible as IC
import ModelingToolkitStandardLibrary.Blocks as B
import ModelingToolkitStandardLibrary.Mechanical.Translational as T


using ModelingToolkitDesigner: ODESystemDesign, DesignColorMap, DesignMap



@parameters t
D = Differential(t)

function system(N; name)

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

res_design_dict = Dict()
for (key, value) in zip(keys(res_design), values(res_design))

    inner_dict = Dict()
    for (ikey, ivalue) in zip(keys(value), values(value))
        push!(inner_dict, ikey => ivalue)
    end

    push!(res_design_dict, key => inner_dict)

end

open("icons/ModelingToolkitStandardLibrary/Hydraulic/IsothermalCompressible/Pipe.toml","w") do io
    TOML.print(io, res_design_dict; sorted=true) do val
        if val isa Symbol
            return string(val)
        end
    end
end

sys_design = [
    :stp => (x=0.0, )
    :src => (x=0.5, input=:W)
    :res => (x=1.0, port_a =:W)
    :vol => (x=1.5, port=:W)

    :fluid => (x=0.5, y=-0.5)
]

design = [
    sys => sys_design
    sys.res => res_design
]

if design isa Vector
    pars = design
    design_dict = Dict()
    for (sys, args) in pars
        push!(design_dict, sys.name => args)
    end
end


@test ModelingToolkitDesigner.get_color(sys.vol.port, maps) == :blue
@test ModelingToolkitDesigner.get_color(sys.vol, maps) == :black

@test lowercase(abspath(ModelingToolkitDesigner.find_icon(sys.vol))) == lowercase(abspath(raw"icons\ModelingToolkitStandardLibrary\Hydraulic\IsothermalCompressible\FixedVolume.png"))

model = ODESystemDesign(nothing, sys, maps, design);

using GLMakie
set_theme!(Theme(fontsize=10))

fig = ModelingToolkitDesigner.view(model)

