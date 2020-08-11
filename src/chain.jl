struct DummyFiltration <: AbstractFiltration{Int, Int} end

Ripserer.simplex_type(::Type{<:DummyFiltration}, D) = Simplex{D, Int, Int}
function Ripserer.unsafe_simplex(
    ::Type{<:AbstractSimplex{D}}, ::DummyFiltration, vertices, sign=1
) where D
    if sign == 1
        Simplex{D}(vertices, 1)
    else
        -Simplex{D}(vertices, 1)
    end
end

function collect_points!(ps, es, Δs, points, sx::AbstractSimplex{0})
    append!(ps, points[sx]), es, Δs
end
function collect_points!(ps, es, Δs, points, sx::AbstractSimplex{1})
    append!(ps, points[sx]), append!(es, points[sx]), Δs
end
@inline function collect_points!(ps, es, Δs, points, sx::AbstractSimplex{2})
    for σ in Ripserer.boundary(DummyFiltration(), sx)
        collect_points!(ps, es, Δs, points, σ)
    end
    return ps, es, append!(Δs, view(points, sx))
end
@inline function collect_points!(ps, es, Δs, points, sx::AbstractSimplex{D}) where D
    for σ in Ripserer.boundary(DummyFiltration(), sx)
        collect_points!(ps, es, Δs, points, σ)
    end
    return ps, es, Δs
end
function collect_points(points, sx::AbstractSimplex)
    vertices, edges, triangles = collect_points!(
        eltype(points)[], eltype(points)[], eltype(points)[], points, sx
    )
    isempty(edges) && push!(edges, points[1])
    isempty(triangles) && push!(edges, points[1])
    return vertices, edges, triangles
end
function collect_points(points, sxs)
    edges = eltype(points)[]
    triangles = eltype(points)[]
    vertices = eltype(points)[]
    for sx in sxs
        collect_points!(vertices, edges, triangles, points, sx)
    end
    # ugly hack
    isempty(edges) && push!(edges, points[1])
    isempty(triangles) && push!(triangles, points[1])
    return vertices, edges, triangles
end
function collect_points(points, chain::AbstractVector{<:AbstractChainElement})
    return collect_points(points, simplex.(chain))
end
function collect_points(points, interval::PersistenceInterval)
    return collect_points(points, representative(interval))
end
function draw_chain(p)
    vertices_edges_triangles = lift(collect_points, p[2], p[1])
    vertices = @lift $(vertices_edges_triangles)[1]
    edges = @lift $(vertices_edges_triangles)[2]
    triangles = @lift $(vertices_edges_triangles)[3]
    mesh!(
        p, triangles;
        color=get_color(p, :trianglecolor),
        shading=p[:shading],
        transparency=p[:transparency],
    )
    linesegments!(p, edges, color=get_color(p, :edgecolor), shading=p[:shading])
    scatter!(p, p[2], color=get_color(p, :pointcolor), markersize=1)
    #TODO vertices/0-homology
end

function AbstractPlotting.default_theme(
    scene::SceneLike, ::Union{
        Type{<:Plot(AbstractSimplex, AbstractVector)},
        Type{<:Plot(AbstractVector{<:AbstractSimplex}, AbstractVector)},
        Type{<:Plot(AbstractVector{<:AbstractChainElement}, AbstractVector)},
        Type{<:Plot(PersistenceInterval, AbstractVector)},
    }
)
    return Theme(
        pointcolor = 1,
        edgecolor = :black,
        trianglecolor = 2,
        shading = false,
        transparency = true,
        palette = DEFAULT_PALETTE,
    )
end
function AbstractPlotting.plot!(p::Plot(AbstractSimplex, AbstractVector))
    draw_chain(p)
end
function AbstractPlotting.plot!(p::Plot(AbstractVector{<:AbstractSimplex}, AbstractVector))
    draw_chain(p)
end
function AbstractPlotting.plot!(p::Plot(AbstractVector{<:AbstractChainElement}, AbstractVector))
    draw_chain(p)
end
function AbstractPlotting.plot!(p::Plot(PersistenceInterval, AbstractVector))
    draw_chain(p)
end
