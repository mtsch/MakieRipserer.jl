using Test
using AbstractPlotting
using MakieRipserer
using Ripserer

import GeometryBasics
using Ripserer: chain_element_type

using MakieRipserer:
    ChainPlot, FilteredVertices, FilteredEdges, FilteredTriangles, FilteredChain

@testset "FilteredChain" begin
    @testset "From filtration" begin
        data = [(sin(t), cos(t)) for t in range(0, 2π; length=13)[1:12]]
        filtration = Rips(data)

        chain = FilteredChain(filtration, data)

        vs = chain.vertices
        es = chain.edges
        ts = chain.triangles

        @test length(vs[0.0]) == 12
        @test length(vs[-0.1]) == 0
        @test length(es[0]) == 0
        for _ in 1:20
            @test iseven(length(es[rand()]))
        end
        @test isempty(ts[0])
        @test ts[0] isa GeometryBasics.Mesh
        @test ts[1] isa GeometryBasics.Mesh
    end
end

@testset "plottype" begin
    data = [(sin(t), cos(t)) for t in range(0, 2π; length=13)[1:12]]
    sx = Simplex{2}(1, 1)
    ch = chain_element_type(typeof(sx), Mod{2})
    @test AbstractPlotting.plottype(sx, data) == ChainPlot
    @test AbstractPlotting.plottype([sx], data) == ChainPlot
    @test AbstractPlotting.plottype(ch(sx), data) == ChainPlot
    @test AbstractPlotting.plottype([ch(sx)], data) == ChainPlot
    @test AbstractPlotting.plottype(Rips(data), data) == ChainPlot
end

@testset "convert_arguments" begin
    data = [(sin(t), cos(t)) for t in range(0, 2π; length=13)[1:12]]
    sx = Simplex{2}(1, 1)
    ch = chain_element_type(typeof(sx), Mod{2})
    @test convert_arguments(ChainPlot, sx, data)[1] isa FilteredChain
    @test convert_arguments(ChainPlot, [sx], data)[1] isa FilteredChain
    @test convert_arguments(ChainPlot, ch(sx), data)[1] isa FilteredChain
    @test convert_arguments(ChainPlot, [ch(sx)], data)[1] isa FilteredChain
    @test convert_arguments(ChainPlot, Rips(data), data)[1] isa FilteredChain
end

@testset "No data error" begin
    data = [(sin(t), cos(t)) for t in range(0, 2π; length=13)[1:12]]
    sx = Simplex{2}(1, 1)
    ch = chain_element_type(typeof(sx), Mod{2})
    @test_throws ArgumentError AbstractPlotting.plot(sx)
    @test_throws ArgumentError AbstractPlotting.plot([sx])
    @test_throws ArgumentError AbstractPlotting.plot(ch(sx))
    @test_throws ArgumentError AbstractPlotting.plot([ch(sx)])
    @test_throws ArgumentError AbstractPlotting.plot(Rips(data))
end
