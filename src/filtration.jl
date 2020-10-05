abstract type FilteredSimplices end

Base.firstindex(fs::FilteredSimplices) = first(fs.times)
Base.lastindex(fs::FilteredSimplices) = last(fs.times)
Base.length(fs::FilteredSimplices) = length(fs.times)

function Base.show(io::IO, fs::F) where F<:FilteredSimplices
    print(io, nameof(F), " t=[", firstindex(fs), ", ", lastindex(fs), "], n=", length(fs))
end

struct FilteredVertices{V, T} <: FilteredSimplices
    vertices::Vector{V}
    times::Vector{T}
end
function FilteredVertices(flt, data)
    simplices = sort!([simplex(flt, Val(0), (v,)) for v in Ripserer.vertices(flt)])
    times = birth.(simplices)

    _data = convert_arguments(Scatter, data)[1]
    vertices = _data[only.(Ripserer.vertices.(simplices))]
    return FilteredVertices(vertices, times)
end
function Base.getindex(v::FilteredVertices, t)
    i = searchsortedlast(v.times, t)
    return view(v.vertices, 1:i)
end

struct FilteredEdges{V, T} <: FilteredSimplices
    edges::Vector{V}
    times::Vector{T}
end
function FilteredEdges(flt, data)
    simplices = sort!(Ripserer.edges(flt))
    times = birth.(simplices)

    _data = convert_arguments(Scatter, data)[1]
    edges = _data[collect(Iterators.flatten(vertices.(simplices)))]
    return FilteredEdges(edges, times)
end
function Base.getindex(v::FilteredEdges, t)
    i = searchsortedlast(v.times, t)
    return view(v.edges, 1:2i)
end

struct FilteredTriangles{F, T, D} <: FilteredSimplices
    faces::Vector{F}
    data::D
    times::Vector{T}
end
function FilteredTriangles(flt, data)
    simplices = sort!(collect(Ripserer.columns_to_reduce(flt, Ripserer.edges(flt))))
    times = birth.(simplices)

    faces = [GeometryBasics.GLTriangleFace(vertices(sx)...) for sx in simplices]
    _data = convert_arguments(Scatter, data)[1]
    return FilteredTriangles(faces, _data, times)
end
function Base.getindex(m::FilteredTriangles, t)
    i = searchsortedlast(m.times, t)
    return GeometryBasics.Mesh(m.data, view(m.faces, 1:i))
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

    vertices = FilteredVertices(flt, pts)
    edges = FilteredEdges(flt, pts)
    triangles = FilteredTriangles(flt, pts)

    drawn_vertices = @lift vertices[$time]
    drawn_edges = @lift edges[$time]
    drawn_triangles = @lift triangles[$time]

    mesh!(
        p, drawn_triangles;
        color=get_color(p, :trianglecolor),
        shading=p[:shading],
        transparency=p[:transparency]
    )
    linesegments!(
        p, drawn_edges;
        color=get_color(p, :edgecolor),
        shading=p[:shading],
        linewidth=p[:linewidth],
    )
    scatter!(
        p, drawn_vertices;
        color=get_color(p, :pointcolor),
        markersize=p[:markersize],
    )
end
