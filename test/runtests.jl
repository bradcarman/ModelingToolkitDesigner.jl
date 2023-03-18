using ModelingToolkitDesigner
using ModelingToolkit

# c1 = ModelingToolkitDesigner.Connector(:H, :blue, :W)
# c2 = ModelingToolkitDesigner.Connector(:H, :blue, :E)
# part1 = ModelingToolkitDesigner.ODESystemDesign(ModelingToolkitDesigner.Parameter[], ModelingToolkitDesigner.State[], ModelingToolkitDesigner.ODESystemDesign[], [c1, c2], Pair[], Equation[], 0.0, 0.0, :part1)


# c3 = ModelingToolkitDesigner.Connector(:H, :blue, :W)
# c4 = ModelingToolkitDesigner.Connector(:T, :green, :E)
# part2 = ModelingToolkitDesigner.ODESystemDesign(ModelingToolkitDesigner.Parameter[], ModelingToolkitDesigner.State[], ModelingToolkitDesigner.ODESystemDesign[], [c3, c4], Pair[], Equation[], 1.0, 0.0, :part2)

# sys = ModelingToolkitDesigner.ODESystemDesign(ModelingToolkitDesigner.Parameter[], ModelingToolkitDesigner.State[], [part1, part2], ModelingToolkitDesigner.Connector[], Pair[], Equation[], 0.0, 0.0, :sys)


# ModelingToolkitDesigner.view(sys)


using ModelingToolkit, OrdinaryDiffEq, Test
import ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible as IC
import ModelingToolkitStandardLibrary.Blocks as B
import ModelingToolkitStandardLibrary.Mechanical.Translational as T


import ModelingToolkitDesigner: ODESystemDesign



@parameters t
D = Differential(t)

function system(N; name, fluid)

    pars = @parameters begin
        fluid = fluid
    end

    systems = @named begin
        stp = B.Step(;height = 10e5, offset = 0, start_time = 0.005, duration = Inf, smooth = 0)
        src = IC.InputSource(;p_int=0)
        vol = IC.FixedVolume(;p_int=0, vol=10.0, fluid)
    end

    if N == 1
        @named res = IC.PipeBase(; p_int=0, area=0.01, length=500.0, fluid)
    else
        @named res = IC.Pipe(N; p_int=0, area=0.01, length=500.0, fluid)
    end
    push!(systems, res)


    eqs = [
        connect(stp.output, src.input)
        connect(src.port, res.port_a)
        connect(res.port_b, vol.port)
    ]

    ODESystem(eqs, t, [], pars; name, systems)
end

@named sys = system(1; fluid = IC.water_20C)


design = [
    sys.stp => (icon="free.png", )

    sys.src => (x=0.5, icon="pressure_source.png")
    sys.src.input => (wall=:W, )

    sys.res => (x=1.0, icon="pipe.png")
    sys.res.port_a => (wall=:W, )

    sys.vol => (x=1.5, icon="volume.png")
    sys.vol.port => (wall=:W, )
]

model = ODESystemDesign(nothing, sys, design)


ModelingToolkitDesigner.view(model)

