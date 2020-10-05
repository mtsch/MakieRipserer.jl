using FileIO
using IterTools
using Makie
using MakieRipserer
using MeshIO
using Ripserer
using SparseArrays
# import Pkg; Pkg.add(url="https://github.com/mtsch/TopologicalDatasets.jl")
using TopologicalDatasets

pts = sample(TopologicalDatasets.Sphere(2), 200)
res = ripserer(pts; reps=true, dim_max=2)

# barcode
bcplt = plot_barcode(res)
save(joinpath(@__DIR__, "assets", "barcode.png"), bcplt)

# diagram
dgplt = plot(res)
save(joinpath(@__DIR__, "assets", "diagram.png"), dgplt)

# cocycle
repplt = plot(pts)
plot!(repplt, res[end][end].representative, pts)
save(joinpath(@__DIR__, "assets", "cocycle.png"), repplt)

# app demo
torus = sample(Torus(r1=3), 1000)

time = Observable(0.0)
torus_app = MakieRipserer.app(torus; time=time)
rng = range(0, 4.5, length=200)
rng = vcat(rng, reverse(rng[2:end-1]))
record(torus_app, joinpath(@__DIR__, "assets", "torus.gif"), rng) do r
    println("time: ", r)
    time[] = r
end

# sublevel cat
cat = load(joinpath(@__DIR__, "assets", "cat.obj"))
cat_pts = cat.position
cat_index = Dict([cat_pts[i] => i for i in 1:length(cat_pts)])
dist = zeros(length(cat_pts), length(cat_pts))
for t in cat
    for (p1, p2) in IterTools.subsets(t, Val(2))
        i = cat_index[p1]
        j = cat_index[p2]
        dist[i, j] = dist[j, i] = max(p1[3], p2[3])
    end
end
for point in cat_pts
    i = cat_index[point]
    dist[i, i] = point[3]
end
cat_flt = Rips(sparse(dist))
time = Observable(-1.0)
cat_app = MakieRipserer.app(cat_pts, cat_flt; time=time, dim_max=2)
rng = range(minimum(Ripserer.births(cat_flt)), maximum(Ripserer.births(cat_flt)), length=200)
rng = vcat(rng, reverse(rng[2:end-1]))
record(cat_app, joinpath(@__DIR__, "assets", "cat.gif"), rng) do r
    println("time: ", r)
    time[] = r
end
