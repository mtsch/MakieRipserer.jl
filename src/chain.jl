# This code is generated to make types specific enough.
# Using Union{Scatter, LineSegments, Mesh} does not work.
for T in (Scatter, LineSegments, Mesh)
    @eval begin
        function AbstractPlotting.convert_arguments(
            ::Type{T}, sx::AbstractSimplex, data::AbstractVector
        ) where T<:$T
            return convert_arguments(T, [sx], data)
        end

        function AbstractPlotting.convert_arguments(
            ::Type{T}, elem::AbstractChainElement, data::AbstractVector
        ) where T<:$T
            return convert_arguments(T, [simplex(elem)], data)
        end

        function AbstractPlotting.convert_arguments(
            ::Type{T}, chain::AbstractVector{<:AbstractChainElement}, data::AbstractVector
        ) where T<:$T
            return convert_arguments(T, simplex.(chain), data)
        end
    end
end
for S in (
    AbstractSimplex,
    AbstractChainElement,
    AbstractVector{<:AbstractSimplex},
    AbstractVector{<:AbstractChainElement}
)
    @eval begin
        function AbstractPlotting.plottype(::$S, ::AbstractVector)
            return ChainPlot
        end
    end
    for T in (Scatter, LineSegments, Mesh)
        @eval begin
            function AbstractPlotting.convert_arguments(::Type{<:$T}, sx::$S)
                _simplex_plot_error(sx)
            end
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

function _simplex_plot_error(arg::T) where T
    throw(ArgumentError("No data provided. To plot $T, use `plot(::$T, data)"))
end
