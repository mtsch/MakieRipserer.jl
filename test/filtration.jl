using Test
using MakieRipserer
using Ripserer

import GeometryBasics

using MakieRipserer: FilteredVertices, FilteredEdges, FilteredTriangles

@testset "FilteredSimplices" begin
    data = [(sin(t), cos(t)) for t in range(0, 2π, length=13)[1:12]]
    filtration = Rips(data)

    vs = FilteredVertices(filtration, data)
    es = FilteredEdges(filtration, data)
    ts = FilteredTriangles(filtration, data)

    @test length(vs[0.0]) == 12
    @test length(vs[-0.1]) == 0
    @test length(es[0]) == 0
    for _ in 1:20
        @test iseven(length(es[rand()]))
    end
    @test isempty(ts[0])
    @test ts[0] isa GeometryBasics.Mesh
    @test ts[1] isa GeometryBasics.Mesh

    # TODO
end
