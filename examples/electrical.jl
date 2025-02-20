using ModelingToolkit
# using ModelingToolkit: t_nounits as t
using ModelingToolkitStandardLibrary.Electrical
using ModelingToolkitStandardLibrary.Blocks: Constant
using ModelingToolkitDesigner
using CairoMakie
using GLMakie

@mtkmodel PassThru2 begin

    @components begin
        p1 = Pin()
        p2 = Pin()
    end

    @equations begin
        connect(p1, p2)
    end
end

@mtkmodel PassThru3 begin

    @components begin
        p1 = Pin()
        p2 = Pin()
        p3 = Pin()
    end

    @equations begin
        connect(p1, p2, p3)
    end
end

@mtkmodel Circuit begin

    @parameters begin
        R = 1.0
        C = 1.0
        V = 1.0
    end

    @components begin
        resistor = Resistor(R = R)
        capacitor = Capacitor(C = C)
        source = Voltage()
        constant = Constant(k = V)
        ground = Ground()
        pt2 = PassThru2()
        pt3 = PassThru3()
    end

    @equations begin
        connect(resistor.p, pt2.p1)
        connect(source.p, pt2.p2)
        connect(source.n, pt3.p2)
        connect(capacitor.n, pt3.p1)
        connect(resistor.n, capacitor.p)
        connect(ground.g, pt3.p3)
        connect(source.V, constant.output)
    end

    # @equations begin
    #     connect(constant.output, source.V)
    #     connect(source.p, resistor.p)
    #     connect(resistor.n, capacitor.p)
    #     connect(capacitor.n, source.n, ground.g)
    # end
end

@named rc = Circuit()

path = joinpath(@__DIR__, "design")
design = ODESystemDesign(rc, path)
GLMakie.set_theme!(Theme(; fontsize = 12))
ModelingToolkitDesigner.view(design)

CairoMakie.set_theme!(Theme(;fontsize=12))
fig = ModelingToolkitDesigner.view(design, false)
save(joinpath(@__DIR__, "electrical.svg"), fig; size=(300,300))
# save(joinpath(@__DIR__, "electrical.svg"), fig; resolution=(300,300))
