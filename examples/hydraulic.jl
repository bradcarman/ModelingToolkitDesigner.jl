using ModelingToolkit
using ModelingToolkitDesigner

import ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible as IC
import ModelingToolkitStandardLibrary.Blocks as B


@parameters t

@component function System(; name)

    pars = []

    systems = @named begin
        fluid = IC.HydraulicFluid(; density = 876, bulk_modulus = 1.2e9, viscosity = 0.034)

        stp = B.Step(; height = 10e5, start_time = 0.005)
        src = IC.InputSource(; p_int = 0)
        vol = IC.FixedVolume(; p_int = 0, vol = 10.0)
        res = IC.Pipe(5; p_int = 0, area = 0.01, length = 500.0)
    end

    eqs = [
        connect(stp.output, src.input)
        connect(src.port, res.port_a)
        connect(vol.port, res.port_b)
        connect(src.port, fluid)
    ]


    ODESystem(eqs, t, [], pars; name, systems)
end

@named sys = System()

path = joinpath(@__DIR__, "design") # folder where visualization info is saved and retrieved
design = ODESystemDesign(sys, path);
ModelingToolkitDesigner.view(design)
