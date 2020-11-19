using Test
using MakieRipserer
using AbstractPlotting
using Ripserer
using Suppressor

@testset "ripserer" begin
    @suppress begin
        data = [Point3f0(rand(), rand(), rand()) for _ = 1:50]
        plt = ReductionPlot(data, Rips(data), debug=true)

        res_coh = ripserer(plt; dim_max=2)
        res_hom = ripserer(plt; dim_max=1, alg=:homology)
        res_inv = ripserer(plt; dim_max=2, alg=:involuted)
        res_nor = ripserer(data; dim_max=2)
        @test res_coh == res_nor
        @test res_hom == res_nor[1:2]
        @test res_inv == res_nor
    end
end
