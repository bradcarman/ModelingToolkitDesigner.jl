using ModelingToolkit
using ModelingToolkitStandardLibrary.Electrical
using ModelingToolkitStandardLibrary.Blocks: Constant
using ModelingToolkitDesigner
using CairoMakie

@component function Circuit(;name)

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
    end
    

    eqs = [connect(constant.output, source.V)
            connect(source.p, resistor.p)
            connect(resistor.n, capacitor.p)
            connect(capacitor.n, source.n, ground.g)]

    ODESystem(eqs, t, [], [];  systems, name)
end

@named rc = Circuit()


path = joinpath(@__DIR__, "design")
design = ODESystemDesign(rc, path)
ModelingToolkitDesigner.view(design)

CairoMakie.set_theme!(Theme(;fontsize=12))
fig = ModelingToolkitDesigner.view(design, false)
save(joinpath(@__DIR__, "electrical.svg"), fig; resolution=(400,400))