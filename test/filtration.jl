using Test
using MakieRipserer
using Ripserer

using MakieRipserer: FilteredSimplices

@testset "FilteredSimplices" begin
    data = [(sin(t), cos(t)) for t in range(0, 2π, length=13)[1:12]]
    filtration = Rips(data)

    vs = FilteredVertices(filtration, data)
    es = FilteredEdges(filtration, data)
    ts = FilteredTriangles(filtration, data)

    @test length(vs[0.0]) == 12
    @test length(vs[-0.1]) == 0

    # TODO
end
