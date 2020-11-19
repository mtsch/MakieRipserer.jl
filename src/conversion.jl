# This file contains conversion functions for converting simplices with data to Scatter,
# LineSegments, and Mesh.

# This code is generated to make types specific enough.
# Using Union{Scatter, LineSegments, Mesh} does not work.
for T in (Scatter, LineSegments, Mesh)
    @eval begin
        function AbstractPlotting.convert_arguments(
            ::Type{T},
            sx::AbstractSimplex,
            data::AbstractVector,
        ) where {T<:$T}
            return convert_arguments(T, [sx], data)
        end

        function AbstractPlotting.convert_arguments(
            ::Type{T},
            elem::AbstractChainElement,
            data::AbstractVector,
        ) where {T<:$T}
            return convert_arguments(T, [simplex(elem)], data)
        end

        function AbstractPlotting.convert_arguments(
            ::Type{T},
            chain::AbstractVector{<:AbstractChainElement},
            data::AbstractVector,
        ) where {T<:$T}
            return convert_arguments(T, simplex.(chain), data)
        end
    end
end

function AbstractPlotting.convert_arguments(
    ::Type{T},
    chain::AbstractVector{<:AbstractSimplex},
    data::AbstractVector,
) where {T<:Scatter}
    _data, = convert_arguments(PointBased(), data)
    points = unique!(collect(Iterators.flatten(_data[sx] for sx in chain)))
    return convert_arguments(T, points)
end
function AbstractPlotting.convert_arguments(
    ::Type{T},
    chain::AbstractVector{<:AbstractSimplex},
    data::AbstractVector,
) where {T<:LineSegments}
    _data, = convert_arguments(PointBased(), data)
    segs = NTuple{2,eltype(data)}[]
    for sx in chain
        for vs in IterTools.subsets(vertices(sx), Val(2))
            push!(segs, getindex.(Ref(data), vs))
        end
    end
    unique!(segs)
    return convert_arguments(T, collect(Iterators.flatten(segs)))
end
function AbstractPlotting.convert_arguments(
    ::Type{T},
    chain::AbstractVector{<:AbstractSimplex},
    data::AbstractVector,
) where {T<:Mesh}
    _data, = convert_arguments(PointBased(), data)
    faces = typeof(GeometryBasics.GLTriangleFace(1, 2, 3))[]
    for sx in chain
        for vs in IterTools.subsets(vertices(sx), Val(3))
            push!(faces, vs)
        end
    end
    return convert_arguments(T, GeometryBasics.Mesh(_data, faces))
end
