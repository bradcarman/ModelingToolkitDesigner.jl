# ModelingToolkitDesigner.jl

The ModelingToolkitDesigner.jl package is a helper tool for visualizing and editing ModelingToolkit.jl system connections.  An example system visualization generated from this package is shown below

![example](https://user-images.githubusercontent.com/40798837/228676202-c13b93c2-d023-4b00-bed8-c8440cb8ca57.png)


# Tutorial

Let's start with a simple hydraulic system with no connections defined yet...

```julia
using ModelingToolkit
using ModelingToolkitDesigner
using GLMakie

import ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible as IC
import ModelingToolkitStandardLibrary.Blocks as B


@parameters t

@component function system(; name)

    pars = []

    systems = @named begin
        stp = B.Step(;height = 10e5, start_time = 0.005)
        src = IC.InputSource(;p_int=0)
        vol = IC.FixedVolume(;p_int=0, vol=10.0)
        res = IC.Pipe(5; p_int=0, area=0.01, length=500.0)
    end
   
    eqs = Equation[]
    
    ODESystem(eqs, t, [], pars; name, systems)
end

@named sys = system()
```

Then we can visualize the system using `ODESystemDesign()` and the `view()` functions

```julia
path = "./design" # folder where visualization info is saved and retrieved
design = ODESystemDesign(sys, path);
ModelingToolkitDesigner.view(design)
```

![step 1](https://user-images.githubusercontent.com/40798837/228621071-2044a422-5a5a-4a3b-89fe-7e4d297f9438.png)

Components can then be positioned in several ways:
- keyboard: select component and then use up, down, left, right keys
- mouse: click and drag (currently only 1 component at a time is supported)
- alignment: select and align horrizontal or vertial with respective buttons

![step2-3](https://user-images.githubusercontent.com/40798837/228626821-9e405ec3-e89b-4f30-bfff-ceb761ea6e2f.png)

Nodes/Connectors can be positioned by selecting with the mouse and using the __move node__ button.  *Note: Components and Nodes can be de-selected by right clicking anywhere or using the button* __clear selection__

![step4-5](https://user-images.githubusercontent.com/40798837/228626824-06f4d432-ea93-408d-ad1a-ddaa6ddc14e6.png)

Connections can then be made by clicking 2 nodes and using the __connect__ button.  One can then click the __save__ button which will store the visualization information in the `path` location in a `.toml` format as well as the connection code in `.jl` format.

![step6-7](https://user-images.githubusercontent.com/40798837/228640663-e263a561-6549-415b-a8ff-b74e78c4bdb9.png)

The connection code can also be obtained with the `connection_code()` function

```julia
julia> connection_code(design)
connect(stp.output, src.input)
connect(src.port, res.port_a)
connect(vol.port, res.port_b)
```

After the original `system()` component function is updated with the connection equations, the connections will be re-drawn automatically when using `ModelingToolkitDesigner.view()`.  *Note: CairoMakie vector based images can also be generated by passing `false` to the 2nd argument of `view()` (i.e. the `interactive` variable).*

# Hierarchy
If a component has a double lined box then it is possible to "look under the hood".  Simply select the component and click __open__.

![step8-9](https://user-images.githubusercontent.com/40798837/228666972-14ea5032-52c6-4447-a97b-383356fbcbcf.png)

Edits made to sub-components can be saved and loaded directly or indirectly.  

# Icons
ModelingToolkitDesigner.jl comes with icons for the ModelingToolkitStandardLibrary.jl pre-loaded.  For custom components, icons are loaded from the `path` variable supplied to `ODESystemDesign()`.  To find the path ModelingToolkitDesign.jl is searching, pass the system of interest to `ODESystemDesign()` and replace the `.toml` with `.png`.  For example if we want to make an icon for the `sys.vol` component, we can find the path by running...

```julia
julia> ODESystemDesign(sys.vol, path).file
"./design\\ModelingToolkitStandardLibrary\\Hydraulic\\IsothermalCompressible\\FixedVolume.toml"
```

Placing a "FixedVolume.png" file in this location will load that icon.

# Colors
ModelingToolkitDesigner.jl colors the connections based on `ModelingToolkitDesigner.design_colors`.  Colors for the ModelingToolkitStandardLibrary.jl are already loaded.  To add a custom connector color, simply use `add_color(system::ODESystem, color::Symbol)` where `system` is a reference to the connector (e.g. `sys.vol.port`) and `color` is a named color from [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/namedcolors/).