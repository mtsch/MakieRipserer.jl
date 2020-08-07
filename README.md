# MakieRipserer.jl

Experimental [Makie](https://github.com/JuliaPlots/Makie.jl) support for
[Ripserer.jl](https://github.com/mtsch/Ripserer.jl/).

# API

```
plot_diagram(diagrams; kwargs...)
plot_barcode(diagrams; kwargs...)
```

Plot the persistence diagram or barcode. Only collections of diagrams currently supported.

Keyword args:

* `infinity`: set the position of infinity line.
* `palette::symbol`: set a palette from
  [ColorSchemes.jl](https://github.com/juliagraphics/colorschemes.jl). defaults to `:tab10`.
* `time::Observable`: optional. Display current time on plot.

```
plot(simplices, points; kwargs...)
```

Plot simplices over points. `simplices` can be an `AbstractSimplex`, a collection of
simplices or `AbstractChainElement`s or `RepresentativeInterval`.

Keyword args:

* `pointcolor`, `edgecolor`, `trianglecolor`: set colors of drawn simplices. Can be an
  `Integer` (position in palette) or color.
* `palette::Symbol`: set a palette from
  [ColorSchemes.jl](https://github.com/JuliaGraphics/ColorSchemes.jl). Defaults to `:tab10`.
* `shading`: defaults to `false`.
* `transparency`: defaults to `true`.

```
plot(::AbstractRipsFiltration, points; time, kwargs...)
```

Plot the triangles and edges of Rips filtration at `time` over points.

Keyword args:

* `pointcolor`, `edgecolor`, `trianglecolor`: set colors of drawn simplices. Can be an
  `Integer` (position in palette) or color.
* `palette::symbol`: set a palette from
  [ColorSchemes.jl](https://github.com/juliagraphics/colorschemes.jl). defaults to `:tab10`.
* `shading`: defaults to `true`.
* `transparency`: defaults to `true`.

```
MakieRipserer.app(points, filtration=Rips(points))
```

![](/docs/src/assets/torus.gif)

![](/docs/src/assets/cat.gif)
