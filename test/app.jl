using AbstractPlotting
using MakieRipserer
using Ripserer
using Suppressor
using Test

@testset "Nothing throws" begin
    data = [(sin(t), cos(t)) for t in range(0, 2π, length = 13)[1:12]]
    time = Observable(0.0)
    @suppress begin
        @test begin
            MakieRipserer.app(data, Rips; time)
            time[] = 1
            true
        end
    end
end
