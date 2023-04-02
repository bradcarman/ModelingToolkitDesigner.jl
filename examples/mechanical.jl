using ModelingToolkit
using ModelingToolkitDesigner

using ModelingToolkitStandardLibrary.Blocks
import ModelingToolkitStandardLibrary.Mechanical.Translational as TV

@parameters t
D = Differential(t)

@component function PassThru3(; name)
    @variables t

    systems = @named begin
        p1 = TV.MechanicalPort()
        p2 = TV.MechanicalPort()
        p3 = TV.MechanicalPort()
    end

    eqs = [connect(p1, p2, p3)]

    return ODESystem(eqs, t, [], []; name, systems)
end

@component function MassSpringDamper(; name)
    systems = @named begin
        dv = TV.Damper(d = 1, v_a_0 = 1)
        sv = TV.Spring(k = 1, v_a_0 = 1, delta_s_0 = 1)
        bv = TV.Mass(m = 1, v_0 = 1)
        gv = TV.Fixed()

        pt1 = PassThru3()
        pt2 = PassThru3()
    end

    eqs = [
        connect(bv.flange, pt2.p2)
        connect(sv.flange_a, pt2.p1)
        connect(dv.flange_a, pt2.p3)
        connect(dv.flange_b, pt1.p3)
        connect(sv.flange_b, pt1.p1)
        connect(gv.flange, pt1.p2)
    ]

    return ODESystem(eqs, t, [], []; name, systems)
end

@named msd = MassSpringDamper()

path = joinpath(@__DIR__, "design")
design = ODESystemDesign(msd, path)
ModelingToolkitDesigner.view(design)

# using CairoMakie
# CairoMakie.set_theme!(Theme(;fontsize=12))
# fig = ModelingToolkitDesigner.view(design, false)
# save(joinpath(@__DIR__, "mechanical.svg"), fig; resolution=(400,200))
