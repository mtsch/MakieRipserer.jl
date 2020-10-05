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

function _collect_simplices(itr, pts)
    fst = first(itr)
    times = fill(zero(birth(fst)), length(fst))
    points = fill(pts[1], length(fst))

    for i in itr
        append!(points, pts[i])
        append!(times, fill(birth(i), length(i)))
    end
    points, times
end

function _collect_simplices(vertices, births, pts)
    perm = sortperm(births)
    return pts[vertices[perm]], births[perm]
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

    edges = sort!(Ripserer.edges(flt))
    edge_ts = birth.(edges)
    triangles = sort!(collect(Ripserer.columns_to_reduce(flt, edges)))
    triangle_ts = birth.(triangles)

    drawn_vertices = lift(p[:time]) do t
        i = searchsortedlast(vertex_ts, t)
        vertices[1:i]
    end
    drawn_edges = lift(p[:time]) do t
        i = searchsortedlast(edge_ts, t)
        edges[1:i]
    end
    drawn_triangles = lift(p[:time], p[:triangles]) do t, tri
        if tri
            i = searchsortedlast(triangle_ts, t)
            triangles[1:i]
        else
            triangles[1:0]
        end
    end
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
