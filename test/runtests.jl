using ModelingToolkitDesigner
using ModelingToolkit, Test

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
        stp = B.Step(;
            height = 10e5,
            offset = 0,
            start_time = 0.005,
            duration = Inf,
            smooth = 0,
        )
        src = IC.InputSource(; p_int = 0)
        vol = IC.FixedVolume(; p_int = 0, vol = 10.0)
        res = IC.Pipe(N; p_int = 0, area = 0.01, length = 500.0)
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

fixed_volume_icon_ans =
    raw"icons\ModelingToolkitStandardLibrary\Hydraulic\IsothermalCompressible\FixedVolume.png"
fixed_volume_icon_ans = abspath(fixed_volume_icon_ans)
fixed_volume_icon_ans = normpath(fixed_volume_icon_ans)
fixed_volume_icon_ans = lowercase(fixed_volume_icon_ans)

fixed_volume_icon = ModelingToolkitDesigner.find_icon(sys.vol, path)
fixed_volume_icon = abspath(fixed_volume_icon)
fixed_volume_icon = normpath(fixed_volume_icon)
fixed_volume_icon = lowercase(fixed_volume_icon)

@test fixed_volume_icon == fixed_volume_icon_ans


design = ODESystemDesign(sys, path);
@test design.components[2].xy[] == (0.58, 0.0)
@test lowercase(abspath(design.components[3].icon)) == fixed_volume_icon
@test_nowarn ModelingToolkitDesigner.view(design)
@test_nowarn ModelingToolkitDesigner.view(design, false)


