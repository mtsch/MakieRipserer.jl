using Test
using AbstractPlotting
using MakieRipserer
using Ripserer

using Ripserer: chain_element_type
using MakieRipserer: ChainPlot

@testset "convert_arguments" begin
    for (f, name) in (
        (identity, "Simplex"),
        (s -> chain_element_type(typeof(s), Mod{2})(s), "ChainElement"),
    )
        @testset "$name single" begin
            data = [(sin(t), cos(t)) for t in range(0, 2π, length=13)[1:12]]
            sx1 = f(Simplex{1}(1, 1))
            @test length(convert_arguments(Scatter, sx1, data)[1]) == 2
            @test length(convert_arguments(LineSegments, sx1, data)[1]) == 2
            @test length(convert_arguments(Mesh, sx1, data)[1]) == 0

            sx3 = f(Simplex{3}(3, 1))
            @test length(convert_arguments(Scatter, sx3, data)[1]) == 4
            @test length(convert_arguments(LineSegments, sx3, data)[1]) == 12
            @test length(convert_arguments(Mesh, sx3, data)[1]) == 4
        end
        @testset "$name collection" begin
            data = [(sin(t), cos(t)) for t in range(0, 2π, length=13)[1:5]]
            sxs = f.([
                Simplex{2}([3, 2, 1], 1), Simplex{2}([4, 3, 2], 1), Simplex{2}([5, 4, 1], 1)
            ])

            @test length(convert_arguments(Scatter, sxs, data)[1]) == 5
            @test length(convert_arguments(LineSegments, sxs, data)[1]) == 16
            @test length(convert_arguments(Mesh, sxs, data)[1]) == 3
        end
    end

    @testset "errors" begin
        for T in (Scatter, LineSegments, Mesh)
            sx = Simplex{1}(1, 1)
            ch = chain_element_type(typeof(sx), Mod{2})(sx)
            @test_throws ArgumentError convert_arguments(T, sx)
            @test_throws ArgumentError convert_arguments(T, ch)
            @test_throws ArgumentError convert_arguments(T, [sx])
            @test_throws ArgumentError convert_arguments(T, [ch])
        end
    end
end

@testset "plottype" begin
    data = [(sin(t), cos(t)) for t in range(0, 2π, length=13)[1:12]]
    sx = Simplex{2}(5, 3)
    ch = chain_element_type(typeof(sx), Mod{2})(sx)

    @test AbstractPlotting.plottype(sx, data) == ChainPlot
    @test AbstractPlotting.plottype(ch, data) == ChainPlot
    @test AbstractPlotting.plottype([sx], data) == ChainPlot
    @test AbstractPlotting.plottype([ch], data) == ChainPlot
end
