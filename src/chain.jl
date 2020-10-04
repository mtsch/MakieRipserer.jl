function _plottable(sxs::AbstractVector{<:AbstractSimplex}, data, ::Val{D}) where D
    result = NTuple{D, eltype(data)}[]
    for sx in sxs
        for vs in IterTools.subsets(vertices(sx), Val(D))
            push!(result, getindex.(Ref(data), vs))
        end
    end
    unique!(result)
    return collect(Iterators.flatten(result))
end

# This code is generated to make types specific enough.
# Using Union{Scatter, LineSegments, Mesh} does not work.
for (type, n) in ((:Scatter, 1), (:LineSegments, 2), (:Mesh, 3))
    @eval begin
        function AbstractPlotting.convert_arguments(
            ::Type{T}, sx::AbstractSimplex, data::AbstractVector
        ) where T<:$type
            return convert_arguments(T, [sx], data)
        end
    end

    @eval begin
        function AbstractPlotting.convert_arguments(
            ::Type{T}, chain::AbstractVector{<:AbstractChainElement}, data::AbstractVector
        ) where T<:$type
            return convert_arguments(T, simplex.(chain), data)
        end
    end

    if n ≤ 2
        @eval begin
        end
    end
end

function AbstractPlotting.convert_arguments(
    ::Type{T}, chain::AbstractVector{<:AbstractSimplex}, data::AbstractVector
) where T<:Scatter
    _data, = convert_arguments(PointBased(), data)
    points = unique!(collect(Iterators.flatten(_data[sx] for sx in chain)))
    return convert_arguments(T, points)
end
function AbstractPlotting.convert_arguments(
    ::Type{T}, chain::AbstractVector{<:AbstractSimplex}, data::AbstractVector
) where T<:LineSegments
    _data, = convert_arguments(PointBased(), data)
    segs = NTuple{2, eltype(data)}[]
    for sx in chain
        for vs in IterTools.subsets(vertices(sx), Val(2))
            push!(segs, getindex.(Ref(data), vs))
        end
    end
    unique!(segs)
    return convert_arguments(T, collect(Iterators.flatten(segs)))
end
function AbstractPlotting.convert_arguments(
    ::Type{T}, chain::AbstractVector{<:AbstractSimplex}, data::AbstractVector
) where T<:Mesh
    _data, = convert_arguments(PointBased(), data)
    tris = NTuple{3, Int}[]
    for sx in chain
        for vs in IterTools.subsets(vertices(sx), Val(3))
            push!(tris, vs)
        end
    end
    faces = transpose(reshape(reinterpret(Int, tris), (3, length(tris))))
    return convert_arguments(T, data, faces)
end

@recipe(ChainPlot, chain, data) do scene
    return Theme(;
        all_points = true,
        CHAIN_ARGS...
    )
end

function AbstractPlotting.plot!(p::ChainPlot)
    mesh!(
        p, p[:chain], p[:data];
        color=get_color(p, :trianglecolor),
        shading=p[:shading],
        transparency=p[:transparency]
    )
    linesegments!(
        p, p[:chain], p[:data];
        color=get_color(p, :edgecolor),
        shading=p[:shading],
        linewidth=p[:linewidth],
    )
    scatter!(
        p, p[:chain], p[:data];
        color=get_color(p, :pointcolor),
        markersize=p[:markersize],
    )
end

function AbstractPlotting.plottype(::AbstractSimplex, ::AbstractVector)
    return ChainPlot
end
function AbstractPlotting.plottype(::AbstractVector{<:AbstractSimplex}, ::AbstractVector)
    return ChainPlot
end
function AbstractPlotting.plottype(::AbstractVector{<:AbstractChainElement}, ::AbstractVector)
    return ChainPlot
end
