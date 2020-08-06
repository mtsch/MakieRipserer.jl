function collect_simplices(itr, pts)
    fst = first(itr)
    times = fill(zero(birth(fst)), length(fst))
    points = fill(pts[1], length(fst))

    for i in itr
        append!(points, pts[i])
        append!(times, fill(birth(i), length(i)))
    end
    points, times
end

function AbstractPlotting.default_theme(
    scene::SceneLike, ::Type{<:Plot(AbstractRipsFiltration, Array)}
)
    return Theme(
        pointcolor = 1,
        edgecolor = :black,
        trianglecolor = 2,
        shading = false,
        time = 0,
        palette = DEFAULT_PALETTE,
        transparency = false,
    )
end

function AbstractPlotting.plot!(p::Plot(AbstractRipsFiltration, Array))
    rips = to_value(p[1])
    pts = to_value(p[2])
    time = p[:time]

    edges = sort!(Ripserer.edges(rips))
    triangles = sort!(collect(Ripserer.columns_to_reduce(rips, edges)))

    edge_pts, edge_ts = collect_simplices(edges, pts)
    tri_pts, tri_ts = collect_simplices(triangles, pts)

    drawn_edges = lift(p[:time]) do t
        i = max(searchsortedlast(edge_ts, t), 1)
        edge_pts[1:i]
    end
    drawn_triangles = lift(p[:time]) do t
        i = max(searchsortedlast(tri_ts, t), 1)
        tri_pts[1:i]
    end

    mesh!(
        p, drawn_triangles,
        color=get_color(p, :trianglecolor),
        shading=p[:shading],
        transparency=p[:transparency],
    )
    linesegments!(p, drawn_edges, color=get_color(p, :edgecolor))
    scatter!(p, pts[vertices(rips)], color=get_color(p, :pointcolor), markersize=3)
end
