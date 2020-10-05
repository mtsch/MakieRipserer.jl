using SafeTestsets

@safetestset "aqua" begin
    include("aqua.jl")
end
@safetestset "chain" begin
    include("chain.jl")
end
@safetestset "filtration" begin
    include("filtration.jl")
end
