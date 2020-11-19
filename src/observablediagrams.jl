struct ObservableDiagram
    intervals::Observable{Vector{Point2f0}}
    ids::Observable{Vector{Int}}
    t_min::Observable{Float64}
    t_max::Observable{Float64}
    infinity::Observable{Float64}
end

function ObservableDiagram(t_min, t_max)
    return ObservableDiagram(Observable(Point2f0[]), Observable(Int[]), t_min, t_max, t_max)
end

function ObservableDiagram(diagram::Vector{<:PersistenceInterval})
    return ObservableDiagram([diagram])
end

function ObservableDiagram(diagrams)
    limits = PersistenceDiagrams.limits(diagrams)
    ids = reduce(vcat, fill(i, length(d)) for (i, d) in enumerate(diagrams))
    intervals =
        collect(Iterators.flatten(convert_arguments(Scatter, diag)[1] for diag in diagrams))
    return ObservableDiagram(intervals, ids, limits...)
end

function Base.show(io::IO, od::ObservableDiagram)
    print(io, "ObservableDiagram with $(length(od)) intervals")
end

Base.length(od::ObservableDiagram) = length(od.intervals[])

function Base.empty!(od::ObservableDiagram)
    od.intervals[] = Point2f0[]
    od.ids[] = Int[]
end

function Base.append!(od::ObservableDiagram, intervals)
    od.intervals[] = append!(od.intervals[], convert_arguments(Scatter, intervals)[1])
    if !isempty(od.ids[])
        od.ids[] = append!(od.ids[], fill(od.ids[][end] + 1, length(intervals)))
    else
        od.ids[] = append!(od.ids[], fill(1, length(intervals)))
    end
    return od
end

function Base.push!(od::ObservableDiagram, interval, id = od.ids[][end] + 1)
    od.intervals[] = push!(od.intervals[], Point2f0(interval[1], interval[2]))
    od.ids[] = push!(od.ids[], id)
    return od
end

function edit_last!(od::ObservableDiagram, interval, id = od.ids[][end])
    od.intervals[][end] = Point2f0(interval[1], interval[2])
    od.intervals[] = od.intervals[]
    od.ids[][end] = id
    od.ids[] = od.ids[]
    return od
end

function Base.pop!(od::ObservableDiagram)
    pop!(od.intervals[])
    od.intervals[] = od.intervals[]
    pop!(od.ids[])
    od.ids[] = od.ids[]
end

function AbstractPlotting.default_theme(scene::SceneLike, ::Type{<:Plot(ObservableDiagram)})
    return Theme(
        palette = DEFAULT_PALETTE,
        color = [],
        infinity = nothing,
        persistence = false,
        gapwidth = 0.1,
    )
end

function transform_intervals(intervals, infinity, persistence)
    map(intervals) do interval
        if persistence
            interval -= Point2f0(0, interval[1])
        end
        if isinf(interval[2])
            interval = Point2f0(interval[1], infinity)
        end
        return interval
    end
end

function AbstractPlotting.plot!(p::Plot(ObservableDiagram))
    diagram = to_value(p[1])
    color = lift(p[:palette], p[:color], diagram.ids) do palette, color, ids
        scheme = PlotUtils.get_colorscheme(palette)
        if isempty(ids)
            RGB{Float64}[]
        else
            [scheme[mod1(get(color, id, id), length(scheme))] for id in ids]
        end
    end
    infinity = @lift isnothing($(p[:infinity])) ? $(diagram.infinity) : $(p[:infinity])
    diagrambackground!(
        p,
        diagram.t_min,
        diagram.t_max,
        infinity;
        gapwidth = p[:gapwidth],
        persistence = p[:persistence],
    )
    points = lift(transform_intervals, diagram.intervals, infinity, p[:persistence])
    scatter!(p, points; color)
end
