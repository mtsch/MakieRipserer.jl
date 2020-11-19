using SafeTestsets

@safetestset "filtered chain" begin
    include("filteredchain.jl")
end
@safetestset "app" begin
    include("app.jl")
end
@safetestset "reduction visualization" begin
    include("reductionvisualization.jl")
end
@safetestset "aqua" begin
    include("aqua.jl")
end
