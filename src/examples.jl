using Makie
using Ripserer
using TopologicalDatasets # ]add https://github.com/mtsch/TopologicalDatasets.jl

torus = sample(Torus(r1=3), 100)
knot = sample(Torus(r1=3), 100)
circ = sample(Noisy(TopologicalDatasets.Sphere(1)), 100)
sphere = sample(TopologicalDatasets.Sphere(2), 100)

MakieRipserer.view(torus)
