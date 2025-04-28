# ModelingToolkitDesigner Release Notes

## v1.4
- supports ModelingToolkit v8 and v9

## v1.3
- updating to ModelingToolkit v9

## v1.1.0
- easier component selection (one only needs to click inside the boarder box)

## v1.0.0
- added icon rotation feature

![rotation](https://github.com/bradcarman/ModelingToolkitDesigner.jl/assets/40798837/8c904030-5d4c-4ba8-a105-f0b098ae842a)

- added keyboard commands
    - m: after selecting a component, use the `m` key to turn dragging on.  This can be easier then clicking and dragging.
    - c: connect
    - r: rotate


## v0.3.0
- Connector nodes are now correctly positioned around the component with natural ordering

![moving](https://user-images.githubusercontent.com/40798837/242108325-0736b264-5374-4b63-8823-589c0e447de7.gif)


## v0.2.0
- Settings Files (*.toml) Updates/Breaking Changes
    - icon rotation now saved with key `r`, previously was `wall` which was not the best name
    - connectors nodes now saved with an underscore: `_name`, this helps prevent a collision with nodes named `x`, `y`, or `r`
