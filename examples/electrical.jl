using ModelingToolkit
using ModelingToolkitStandardLibrary.Electrical
using ModelingToolkitStandardLibrary.Blocks: Constant
using ModelingToolkitDesigner
using CairoMakie
using GLMakie

@component function PassThru2(; name)
    @variables t

    systems = @named begin
        p1 = Pin()
        p2 = Pin()
    end

    eqs = [connect(p1, p2)]

    return ODESystem(eqs, t, [], []; name, systems)
end

@component function PassThru3(; name)
    @variables t

    systems = @named begin
        p1 = Pin()
        p2 = Pin()
        p3 = Pin()
    end

    eqs = [connect(p1, p2, p3)]

    return ODESystem(eqs, t, [], []; name, systems)
end

@component function Circuit(; name)

    R = 1.0
    C = 1.0
    V = 1.0
    @variables t

    systems = @named begin
        resistor = Resistor(R = R)
        capacitor = Capacitor(C = C)
        source = Voltage()
        constant = Constant(k = V)
        ground = Ground()
        pt2 = PassThru2()
        pt3 = PassThru3()
    end

    eqs = [
        connect(resistor.p, pt2.p1)
        connect(source.p, pt2.p2)
        connect(source.n, pt3.p2)
        connect(capacitor.n, pt3.p1)
        connect(resistor.n, capacitor.p)
        connect(ground.g, pt3.p3)
        connect(source.V, constant.output)
    ]

    # eqs = [connect(constant.output, source.V)
    #         connect(source.p, resistor.p)
    #         connect(resistor.n, capacitor.p)
    #         connect(capacitor.n, source.n, ground.g)]

    ODESystem(eqs, t, [], []; systems, name)
end

@named rc = Circuit()

# using OrdinaryDiffEq
# sys = structural_simplify(rc)
# prob = ODEProblem(sys, Pair[], (0, 10.0))
# sol = solve(prob, Tsit5())

path = joinpath(@__DIR__, "design")
design = ODESystemDesign(rc, path)
GLMakie.set_theme!(Theme(; fontsize = 12))
ModelingToolkitDesigner.view(design)

# CairoMakie.set_theme!(Theme(;fontsize=12))
# fig = ModelingToolkitDesigner.view(design, false)
# save(joinpath(@__DIR__, "electrical.svg"), fig; resolution=(400,400))
