using ModelingToolkitDesigner
using ModelingToolkit, OrdinaryDiffEq, Test
using TOML
import ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible as IC
import ModelingToolkitStandardLibrary.Blocks as B
import ModelingToolkitStandardLibrary.Mechanical.Translational as T
using GLMakie


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
   
    eqs = Equation[
        connect(stp.output, src.input)
        connect(src.port, res.port_a)
        connect(vol.port, res.port_b)
        connect(src.port, fluid)
    ]
    
    ODESystem(eqs, t, [], pars; name, systems)
end

@named sys = system(5)


@test ModelingToolkitDesigner.get_color(sys.vol.port) == :blue
@test ModelingToolkitDesigner.get_color(sys.vol) == :black

path = joinpath(@__DIR__, "designs");

fixed_volume_icon = lowercase(abspath(raw"icons\ModelingToolkitStandardLibrary\Hydraulic\IsothermalCompressible\FixedVolume.png"))

@test lowercase(abspath(ModelingToolkitDesigner.find_icon(sys.vol, path))) == fixed_volume_icon


design = ODESystemDesign(sys, path);
@test design.components[2].xy[] == (0.5, 0.0)
@test lowercase(abspath(design.components[3].icon)) == fixed_volume_icon

# using GLMakie
# set_theme!(Theme(fontsize=10))

fig = ModelingToolkitDesigner.view(design);
display(GLMakie.Screen(;title=design.file), fig)

# fig = ModelingToolkitDesigner.view(design.systems[4]);
# display(GLMakie.Screen(), fig)

fig = ModelingToolkitDesigner.view(design, false);