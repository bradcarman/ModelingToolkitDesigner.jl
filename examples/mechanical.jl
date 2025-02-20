using ModelingToolkit
using ModelingToolkitDesigner

using ModelingToolkitStandardLibrary.Blocks
import ModelingToolkitStandardLibrary.Mechanical.Translational as TV

@mtkmodel PassThru3 begin

    @components begin
        p1 = TV.MechanicalPort()
        p2 = TV.MechanicalPort()
        p3 = TV.MechanicalPort()
    end

    @equations begin
        connect(p1, p2, p3)
    end
end

@mtkmodel MassSpringDamper begin
    @components begin
        dv = TV.Damper(d = 1)
        sv = TV.Spring(k = 1)
        bv = TV.Mass(m = 1)
        gv = TV.Fixed()

        pt1 = PassThru3()
        pt2 = PassThru3()
    end

    @equations begin
        connect(bv.flange, pt2.p2)
        connect(sv.flange_a, pt2.p1)
        connect(dv.flange_a, pt2.p3)
        connect(dv.flange_b, pt1.p3)
        connect(sv.flange_b, pt1.p1)
        connect(gv.flange, pt1.p2)
    end
end

@named msd = MassSpringDamper()

path = joinpath(@__DIR__, "design")
design = ODESystemDesign(msd, path)
ModelingToolkitDesigner.view(design)

using CairoMakie
CairoMakie.set_theme!(Theme(;fontsize=12))
fig = ModelingToolkitDesigner.view(design, false)
save(joinpath(@__DIR__, "mechanical.svg"), fig; size=(400,200))
# save(joinpath(@__DIR__, "mechanical.svg"), fig; resolution=(400,200))
