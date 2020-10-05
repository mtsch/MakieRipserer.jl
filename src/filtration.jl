"""
    FilteredSimplices{S, T}

This struct allows quick filtering of simplices. To construct, use

    FilteredSimplice(::AbstractFiltration, ::Val{D})
"""
struct FilteredSimplices{S, T}
    simplices::Vector{S}
    times::Vector{T}
end

function FilteredSimplices(flt::AbstractFiltration, ::Val{0})
    simplices = sort!([simplex(flt, Val(0), (v,)) for v in Ripserer.vertices(flt)])
    times = birth.(simplices)
    FilteredSimplices(simplices, times)
end
function FilteredSimplices(flt::AbstractFiltration, ::Val{1})
    simplices = sort!(Ripserer.edges(flt))
    times = birth.(simplices)
    FilteredSimplices(simplices, times)
end
function FilteredSimplices(flt::AbstractFiltration, ::Val{2})
    simplices = sort!(collect(Ripserer.columns_to_reduce(flt, Ripserer.edges(flt))))
    times = birth.(simplices)
    FilteredSimplices(simplices, times)
end
function Base.getindex(flt::FilteredSimplices, time)
    i = searchsortedlast(flt.times, time)
    return view(flt.simplices, 1:i)
end

function AbstractPlotting.default_theme(
    scene::SceneLike, ::Type{<:Plot(AbstractFiltration, AbstractVector)}
)
    return Theme(
        ;
        time=Inf,
        triangles=true,
        CHAIN_ARGS...
    )
end

function AbstractPlotting.plot!(p::Plot(AbstractFiltration, AbstractVector))
    flt = to_value(p[1])
    pts = to_value(p[2])
    time = p[:time]

    vertices = FilteredSimplices(flt, Val(0))
    edges = FilteredSimplices(flt, Val(1))
    triangles = FilteredSimplices(flt, Val(2))

    drawn_vertices = @lift vertices[$time]
    drawn_edges = @lift edges[$time]
    drawn_triangles = @lift triangles[$time]

    mesh!(
        p, drawn_triangles, pts;
        color=get_color(p, :trianglecolor),
        shading=p[:shading],
        transparency=p[:transparency]
    )
    linesegments!(
        p, drawn_edges, pts;
        color=get_color(p, :edgecolor),
        shading=p[:shading],
        linewidth=p[:linewidth],
    )
    scatter!(
        p, drawn_vertices, pts;
        color=get_color(p, :pointcolor),
        markersize=p[:markersize],
    )
end
