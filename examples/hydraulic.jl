using ModelingToolkit
using ModelingToolkitDesigner

import ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible as IC
import ModelingToolkitStandardLibrary.Blocks as B

@mtkmodel HydraulicSystem begin

    @components begin
        fluid = IC.HydraulicFluid(; density = 876, bulk_modulus = 1.2e9, viscosity = 0.034)

        stp = B.Step(; height = 10e5, start_time = 0.005)
        src = IC.Pressure()
        vol = IC.FixedVolume(; vol = 10.0)
        res = IC.Tube(; N = 5, area = 0.01, length = 500.0)
    end

    @equations begin
        connect(stp.output, src.p)
        connect(src.port, res.port_a)
        connect(vol.port, res.port_b)
        connect(src.port, fluid)
    end

end

@named sys = System()

path = joinpath(@__DIR__, "design") # folder where visualization info is saved and retrieved
design = ODESystemDesign(sys, path);
ModelingToolkitDesigner.view(design)

using CairoMakie
CairoMakie.set_theme!(Theme(;fontsize=12))
fig = ModelingToolkitDesigner.view(design, false)
save(joinpath(@__DIR__, "hydraulic.svg"), fig; size=(400,200))
