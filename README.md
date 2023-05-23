# ModelingToolkitDesigner.jl

The ModelingToolkitDesigner.jl package is a helper tool for visualizing and editing ModelingToolkit.jl system connections.  

# Updates
## v0.3.0
- Settings Files (*.toml) Updates/Breaking Changes
    - icon rotation now saved with key `r`, previously was `wall` which was not the best name
    - connectors nodes now saved with an underscore: `_name`, this helps prevent a collision with nodes named `x`, `y`, or `r`

## Examples
Examples can be found in the "examples" folder.

### Hydraulic Example

![example2](examples/hydraulic.svg)

### Electrical Example

![example2](examples/electrical.svg)

### Mechanical Example

![example3](examples/mechanical.svg)

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
path = joinpath(@__DIR__, "design") # folder where visualization info is saved and retrieved
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

# Pass Thrus
To generate more esthetic diagrams, one can use as special kind of component called a `PassThru`, which simply defines 2 or more connected `connectors` to serve as a corner, tee, or any other junction.  Simply define a component function starting with `PassThru` and ModelingToolkitDesigner.jl will recognize it as a special component type.  For example for a corner with 2 connection points:


```julia
@component function PassThru2(;name)
    @variables t
    
    systems = @named begin
        p1 = Pin()
        p2 = Pin()
    end

    eqs = [
        connect(p1, p2)
    ]

    return ODESystem(eqs, t, [], []; name, systems)
end
```

And for a tee with 3 connection points

```julia
@component function PassThru3(;name)
    @variables t
    
    systems = @named begin
        p1 = Pin()
        p2 = Pin()
        p3 = Pin()
    end

    eqs = [
        connect(p1, p2, p3)
    ]

    return ODESystem(eqs, t, [], []; name, systems)
end
```

Adding these components to your system will then allow for corners, tees, etc. to be created.  When editing is complete, use the toggle switch to hide the `PassThru` details, showing a more esthetic connection diagram.

![step10-11](https://user-images.githubusercontent.com/40798837/229201536-4444a037-18b3-4efd-bc93-d2c182abf533.png)
 

# Icons
ModelingToolkitDesigner.jl comes with icons for the ModelingToolkitStandardLibrary.jl pre-loaded.  For custom components, icons are loaded from either the `path` variable supplied to `ODESystemDesign()` or from an `icons` folder of the package namespace.  To find the paths ModelingToolkitDesign.jl is searching, run the following on the component of interest (for example `sys.vol`)

```julia
julia> println.(ModelingToolkitDesigner.get_icons(sys.vol, path));
...\ModelingToolkitDesigner.jl\examples\design\ModelingToolkitStandardLibrary\Hydraulic\IsothermalCompressible\FixedVolume.png
...\ModelingToolkitStandardLibrary.jl\icons\ModelingToolkitStandardLibrary\Hydraulic\IsothermalCompressible\FixedVolume.png      
...\ModelingToolkitDesigner.jl\icons\ModelingToolkitStandardLibrary\Hydraulic\IsothermalCompressible\FixedVolume.png
```

The first file location comes from the `path` variable.  The second is looking for a folder `icons` in the component parent package, in this case `ModelingToolkitStandardLibrary`, and the third path is from the `icons` folder of this `ModelingToolkitDesigner` package.  The first real file is the chosen icon load path.  Feel free to contribute icons here for any other public component libraries.

## Icon Rotation
The icon rotation is controlled by the `r` atribute in the saved `.toml` design file.  Currently this must be edited by hand.  The default direction is "E" for east.  The image direciton can change to any "N","S","E","W".  For example, to rotate the capacitor icon by -90 degrees (i.e. from "E" to "N") simply edit the design file as

```
[capacitor]
_n = "S"
x = 0.51
y = 0.29
r = "N"
```

# Colors
ModelingToolkitDesigner.jl colors the connections based on `ModelingToolkitDesigner.design_colors`.  Colors for the ModelingToolkitStandardLibrary.jl are already loaded.  To add a custom connector color, simply use `add_color(system::ODESystem, color::Symbol)` where `system` is a reference to the connector (e.g. `sys.vol.port`) and `color` is a named color from [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/namedcolors/).

# TODO
- Finish adding icons for the ModelingToolkitStandardLibrary.jl
- Rotate image feature
- Improve text positioning and fontsize
- How to include connection equations automatically, maybe implement the `input` macro
- Provide `PassThru`'s without requiring user to add `PassThru` components to ODESystem
- Add documentation

# [compat]
- ModelingToolkit = "8.50" > needed for Domain feature
- ModelingToolkitStandardLibrary = "1.12" > needed for Hydraulic components