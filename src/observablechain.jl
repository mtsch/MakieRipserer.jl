"""
    ObservableChain

A collection of simplices that acts like an observable. When you want to plot a chain that
changes over time, wrap it in this type. Updating it with `setindex` will also update the
plot.

# Example

julia> using Ripserer

julia> simplices = [Simplex{2}(1, 1), Simplex{2}(2, 2)];

julia> data = [(0, 0), (0, 1), (1, 0), (1, 1)];

julia> oc = ObservableChain(simplices, data)
ObservableChain(nv=4, ne=5, nt=2)

julia> oc[] = []; # or ()

julia> oc
ObservableChain(nv=0, ne=0, nt=0)

julia> oc[] = simplices;

julia> oc
ObservableChain(nv=4, ne=5, nt=2)

"""
struct ObservableChain{V, E, T, D}
    vertices::Observable{V}
    edges::Observable{E}
    triangles::Observable{T}
    data::D
end

function ObservableChain(chain, data)
    data = collect(data)
    return ObservableChain(
        Observable(convert_arguments(Scatter, chain, data)[1]),
        Observable(convert_arguments(LineSegments, chain, data)[1]),
        Observable(convert_arguments(Mesh, chain, data)[1]),
        convert_arguments(Scatter, data)[1],
    )
end
function ObservableChain(data)
    ObservableChain(Simplex{1, Int, Int}[], data)
end

function Base.show(io::IO, ch::ObservableChain)
    nv = length(ch.vertices[])
    ne = length(ch.edges[]) ÷ 2
    nt = length(ch.triangles[])
    print(io, "ObservableChain(nv=$nv, ne=$ne, nt=$nt)")
end

function Base.setindex!(oc::ObservableChain, chain)
    if isempty(chain)
        oc.vertices[] = eltype(oc.vertices)[]
        oc.edges[] = eltype(oc.edges)[]
        oc.triangles[] = GeometryBasics.Mesh(oc.data, typeof(GLTriangleFace(1,2,3))[])
    else
        oc.vertices[] = convert_arguments(Scatter, chain, oc.data)[1]
        oc.edges[] = convert_arguments(LineSegments, chain, oc.data)[1]
        oc.triangles[] = convert_arguments(Mesh, chain, oc.data)[1]
    end
end

function AbstractPlotting.default_theme(scene::SceneLike, ::Type{<:Plot(ObservableChain)})
    Theme(
        palette=DEFAULT_PALETTE,
        color=1,
    )
end

function AbstractPlotting.plot!(p::Plot(ObservableChain))
    oc = to_value(p[1])
    color = get_color(p, p[:color])
    dim_is_1 = @lift length($(oc.triangles)) == 0
    edgecolor = @lift $dim_is_1 ? $color : RGB(0.0, 0.0, 0.0)
    linewidth = @lift $dim_is_1 ? 5 : 1

    mesh!(p, oc.triangles; color, shading=false)
    linesegments!(p, oc.edges; color=edgecolor, linewidth, shading=false)
    scatter!(p, oc.vertices; color)
end
