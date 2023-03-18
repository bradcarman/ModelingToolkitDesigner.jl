using GLMakie

xy = Observable((1.0, 1.0))

xso = Observable(zeros(5))
yso = Observable(zeros(5))

on(xy) do val
    xs, ys = ModelingToolkitDesigner.box(val[1], val[2])
    xso[] = xs
    yso[] = ys
end

color=Observable(:black)



fig, ax, l = lines(xso, yso; color)

ylims!(ax, 0.0, 10.0)
xlims!(ax, 0.0, 10.0)