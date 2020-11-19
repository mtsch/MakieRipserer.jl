using Test
using MakieRipserer
using AbstractPlotting
using Ripserer

@testset "vis_ripserer" begin
    data = [Point2f0(rand(), rand(), rand()) for _ = 1:50]

    @test vis_ripserer(data, Rips(data); dim_max = 2)[1] == ripserer(data; dim_max = 2)
    @test vis_ripserer(data, Rips(data); dim_max = 2, alg = :homology)[1] ==
          ripserer(data; dim_max = 2, alg = :homology)
    @test vis_ripserer(data, Rips(data); dim_max = 2, alg = :involuted)[1] ==
          ripserer(data; dim_max = 2, alg = :involuted)
end
