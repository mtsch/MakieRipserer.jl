# This file contains the recipes for plotting collections of simplices filtered by birth
# time. This also includes filtrations.

"""
    FilteredFaces

Abstract type for [`FilteredVertices`](@ref), [`FilteredEdges`](@ref), and
[`FilteredTriangles`](@ref).

The structures contain plotting data and a vector of times. Indexing into them with a time
returns an object that can be plotted without conversion.
"""
abstract type FilteredFaces end

Base.firstindex(fs::FilteredFaces) = first(fs.times)
Base.lastindex(fs::FilteredFaces) = last(fs.times)
Base.length(fs::FilteredFaces) = length(fs.times)

function Base.show(io::IO, fs::F) where {F<:FilteredFaces}
    print(io, nameof(F), " t=[", firstindex(fs), ", ", lastindex(fs), "], n=", length(fs))
    return nothing
end

"""
    FilteredVertices{V, T}

See: [`FilteredFaces`](@ref).
"""
struct FilteredVertices{V,T} <: FilteredFaces
    vertices::Vector{V}
    times::Vector{T}
end
function Base.getindex(v::FilteredVertices, t)
    i = searchsortedlast(v.times, t)
    return v.vertices[1:i]
end

"""
    FilteredEdges{V, T}

See: [`FilteredFaces`](@ref).
"""
struct FilteredEdges{V,T} <: FilteredFaces
    edges::Vector{V}
    times::Vector{T}
end
function Base.getindex(v::FilteredEdges, t)
    i = searchsortedlast(v.times, t)
    return v.edges[1:(2i)]
end

"""
    FilteredTriangles{F, D, T}

See: [`FilteredFaces`](@ref).
"""
struct FilteredTriangles{F,D,T} <: FilteredFaces
    faces::Vector{F}
    data::D
    times::Vector{T}
end
function Base.getindex(m::FilteredTriangles, t)
    i = searchsortedlast(m.times, t)
    return GeometryBasics.Mesh(m.data, m.faces[1:i])
end

"""
    FilteredChain

Contains plotting data to plot a collection of simplices. To construct it, use
`FilteredChain(simplices_or_filtration, data)`. The `data` should be something Makie can
convert to points.

# Example

julia> using Ripserer

julia> simplices = [Simplex{2}(1, 1), Simplex{2}(2, 2)];

julia> data = [(0, 0), (0, 1), (1, 0), (1, 1)];

julia> fc = FilteredChain(simplices, data)
FilteredChain(nv=4, ne=5, nt=2)

"""
struct FilteredChain{V<:FilteredVertices,E<:FilteredEdges,T<:FilteredTriangles}
    vertices::V
    edges::E
    triangles::T
end
function FilteredChain(flt::AbstractFiltration, data)
    points = convert_arguments(Scatter, data)[1]

    vertex_sxs = sort!([simplex(flt, Val(0), (v,)) for v in Ripserer.vertices(flt)])
    vertex_times = birth.(vertex_sxs)
    vertices = points[only.(Ripserer.vertices.(vertex_sxs))]

    edge_sxs = sort!(Ripserer.edges(flt))
    edge_times = birth.(edge_sxs)
    edges = points[collect(Iterators.flatten(Ripserer.vertices.(edge_sxs)))]

    triangle_sxs = sort!(collect(Ripserer.columns_to_reduce(flt, edge_sxs)))
    triangle_times = birth.(triangle_sxs)
    triangle_faces = typeof(GLTriangleFace(1, 2, 3))[]
    for sx in triangle_sxs
        vs = Ripserer.vertices(sx)
        push!(triangle_faces, GLTriangleFace(vs[1], vs[2], vs[3]))
    end

    return FilteredChain(
        FilteredVertices(vertices, vertex_times),
        FilteredEdges(edges, edge_times),
        FilteredTriangles(triangle_faces, points, triangle_times),
    )
end

function FilteredChain(sxs, data)
    points = convert_arguments(Scatter, data)[1]
    sxs = sort(sxs)

    # *_idx is used to prevent plotting faces multiple times
    vertex_times = Float64[]
    vertices = eltype(points)[]
    vertex_idx = Dict{Int,Int}()
    edge_times = Float64[]
    edges = eltype(points)[]
    edge_idx = Dict{Tuple{Int,Int},Int}()
    triangle_times = Float64[]
    triangle_faces = typeof(GLTriangleFace(1, 2, 3))[]
    triangle_idx = Dict{Tuple{Int,Int,Int},Int}()

    for sx in sxs
        sx_vertices = Ripserer.vertices(sx)
        t = birth(sx)
        for v in sx_vertices
            if !haskey(vertex_idx, v)
                push!(vertices, points[v])
                push!(vertex_times, t)
                vertex_idx[v] = lastindex(vertex_times)
            else
                i = vertex_idx[v]
                vertex_times[i] = min(vertex_times[i], t)
            end
        end
        for (u, v) in IterTools.subsets(sx_vertices, Val(2))
            if !haskey(edge_idx, (u, v))
                append!(edges, (points[u], points[v]))
                push!(edge_times, t)
                edge_idx[(u, v)] = lastindex(edge_times)
            else
                i = edge_idx[(u, v)]
                edge_times[i] = min(edge_times[i], t)
            end
        end
        for (u, v, w) in IterTools.subsets(sx_vertices, Val(3))
            if !haskey(triangle_idx, (u, v, w))
                push!(triangle_faces, GLTriangleFace(u, v, w))
                push!(triangle_times, t)
                triangle_idx[(u, v, w)] = lastindex(triangle_times)
            else
                i = triangle_idx[(u, v, w)]
                triangle_times[i] = min(triangle_times[i], t)
            end
        end
    end

    return FilteredChain(
        FilteredVertices(vertices, vertex_times),
        FilteredEdges(edges, edge_times),
        FilteredTriangles(triangle_faces, points, triangle_times),
    )
end

function FilteredChain(sx::AbstractSimplex, data)
    return FilteredChain([sx], data)
end
function FilteredChain(sx::AbstractChainElement, data)
    return FilteredChain([simplex(sx)], data)
end
function FilteredChain(sx::AbstractVector{<:AbstractChainElement}, data)
    return FilteredChain(simplex.(sx), data)
end

function Base.show(io::IO, chain::FilteredChain)
    nv = length(chain.vertices)
    ne = length(chain.edges)
    nt = length(chain.triangles)
    print(io, "FilteredChain(nv=$nv, ne=$ne, nt=$nt)")
    return nothing
end

@recipe(ChainPlot, chain) do scene
    Theme(;
        vertexcolor=1,
        edgecolor=:black,
        trianglecolor=2,
        shading=false,
        transparency=false,
        palette=DEFAULT_PALETTE,
        markersize=10,
        linewidth=1,
        triangles=true,
        edges=true,
        time=Inf,
    )
end

function AbstractPlotting.plot!(p::ChainPlot)
    chain = to_value(p[:chain])
    time = p[:time]
    draw_triangles = @lift length(chain.triangles) > 0 ? $(p[:triangles]) : false
    draw_edges = @lift length(chain.edges) > 0 ? $(p[:edges]) : false

    drawn_vertices = @lift chain.vertices[$time]
    drawn_edges = @lift chain.edges[$draw_edges ? $time : -Inf]
    drawn_triangles = @lift chain.triangles[$draw_triangles ? $time : -Inf]

    mesh!(
        p,
        drawn_triangles;
        color=get_color(p, p[:trianglecolor]),
        shading=p[:shading],
        transparency=p[:transparency],
    )
    linesegments!(
        p,
        drawn_edges;
        color=get_color(p, p[:edgecolor]),
        shading=p[:shading],
        linewidth=p[:linewidth],
    )
    return scatter!(
        p, drawn_vertices; color=get_color(p, p[:vertexcolor]), markersize=p[:markersize]
    )
end

function _no_data_error(arg::T) where {T}
    return throw(ArgumentError("No data provided. To plot $T, use `plot(::$T, data)"))
end

for T in (
    AbstractFiltration,
    AbstractSimplex,
    AbstractChainElement,
    AbstractVector{<:AbstractSimplex},
    AbstractVector{<:AbstractChainElement},
)
    @eval begin
        function AbstractPlotting.plottype(::$T, ::AbstractVector)
            return ChainPlot
        end
        function AbstractPlotting.convert_arguments(::Type{<:ChainPlot}, x::$T, data)
            return (FilteredChain(x, data),)
        end
        function AbstractPlotting.plottype(x::$T)
            return _no_data_error(x)
        end
    end
end

"""
    chainplot(x, data)

Plot a simplex, collection of simplices, or filtration. Data is used to determine vertex
locations. Setting the `time` filters plotted simplices by birth.

Names or `Int`s can be used to set colors.

# Attributes

    vertexcolor   1
    edgecolor     :black
    trianglecolor 2
    shading       false
    transparency  false
    palette       :default
    markersize    10
    linewidth     1
    triangles     true
    edges         true
    time          Inf

"""
chainplot

"""
    chainplot!(x, data)

Plot a simplex, collection of simplices, or filtration. Data is used to determine vertex
locations. Setting the `time` filters plotted simplices by birth.

Names or `Int`s can be used to set colors.

# Attributes

    vertexcolor   1
    edgecolor     :black
    trianglecolor 2
    shading       false
    transparency  false
    palette       :default
    markersize    10
    linewidth     1
    triangles     true
    edges         true
    time          Inf

"""
chainplot!
