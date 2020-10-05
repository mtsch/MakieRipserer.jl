using Test
using MakieRipserer
using Ripserer

using MakieRipserer: FilteredSimplices

@testset "FilteredSimplices" begin
    data = [(sin(t), cos(t)) for t in range(0, 2π, length=13)[1:12]]
    filtration = Rips(data)

    vs = FilteredSimplices(filtration, Val(0))
    es = FilteredSimplices(filtration, Val(1))
    ts = FilteredSimplices(filtration, Val(2))

    @test eltype(vs[0]) == Simplex{0, Float64, Int}
    @test eltype(es[0]) == Simplex{1, Float64, Int}
    @test eltype(ts[0]) == Simplex{2, Float64, Int}

    @test length(vs[0.0]) == 12
    @test length(vs[-0.1]) == 0

    @test maximum(birth, es[1.0]) ≤ 1.0
    @test maximum(birth, ts[1.0]) ≤ 1.0

    @test es[Inf] == sort!(Ripserer.edges(filtration))
end
