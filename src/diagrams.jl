function guess_infinity(diagram, infinity)
    if isnothing(infinity)
        if hasproperty(diagram, :threshold)
            thresh = threshold(diagram)
        else
            thresh = nothing
        end
        if isnothing(thresh) || ismissing(thresh) || isinf(thresh)
            return 1.1 * maximum(Iterators.filter(isfinite, Iterators.flatten(diagram)))
        else
            return thresh
        end
    else
        return infinity
    end
end

function AbstractPlotting.convert_arguments(
    ::Type{<:Scatter}, intervals::AbstractVector{<:PersistenceInterval}
)
    return ([Point2f0(birth(int), death(int)) for int in intervals],)
end

@recipe(DiagramBackground) do scene
    return Theme(
        persistence=false,
        gapwidth=0.1,
    )
end

function AbstractPlotting.plot!(p::DiagramBackground)
    t_lo = p[1]
    t_hi = p[2]
    inf_val = p[3]
    persistence = p[:persistence]
    gap = @lift ($t_hi - $t_lo) * $(p[:gapwidth])

    persistence_line = lift(t_lo, t_hi, gap, persistence) do t_lo, t_hi, gap, persistence
        if persistence
            return [Point2f0(t_lo - gap, 0), Point2f0(t_hi + gap, 0)]
        else
            return [Point2f0(t_lo - gap, t_lo - gap), Point2f0(t_hi + gap, t_hi + gap)]
        end
    end
    lines!(p, persistence_line)

    inf_line = @lift [Point2f0($t_lo - $gap, $inf_val), Point2f0($t_hi + $gap, $inf_val)]
    lines!(p, inf_line, linestyle=:dot, color=:gray)
end

@recipe(DiagramPlot, diagram) do scene
    return Theme(
        palette=DEFAULT_PALETTE,
        color=1,
        infinity=nothing,
        persistence=false,
    )
end

function AbstractPlotting.plot!(p::DiagramPlot)
    diag = p[1]
    infinity = @lift guess_infinity($diag, $(p[:infinity]))
    points = lift(diag, infinity, p[:persistence]) do diag, infinity, persistence
        pts = convert_arguments(Scatter, diag)[1]
        for i in eachindex(pts)
            if persistence
                pts[i] -= Point2f0(0, pts[i][1])
            end
            if isinf(pts[i][2])
                pts[i] = Point2f0(pts[i][1], infinity)
            end
        end
        return pts
    end
    scatter!(p, points; color=get_color(p, p[:color]))
end

function AbstractPlotting.default_theme(
    scene::SceneLike, ::Type{<:Plot(PersistenceDiagram)}
)
    return Theme(
        color=:gray,
        infinity=nothing,
        persistence=false,
    )
end

function plot_diagram!(
    scene,
    diags;
    infinity=nothing,
    persistence=false,
    palette=DEFAULT_PALETTE,
    time=Observable(nothing),
    gapwidth=0.1,
)
    if !(time isa Observable)
        time = Observable(time)
    end
    t_lo, t_hi, inf_val = PersistenceDiagrams.limits(diags, infinity)
    width = t_hi - t_lo
    gap = width * gapwidth

    diagrambackground!(scene, t_lo, t_hi, inf_val; persistence, gapwidth)

    for (i, diag) in enumerate(diags)
        !isempty(diag) && diagramplot!(
            scene, diag;
            infinity=infinity,
            persistence=persistence,
            color=i,
        )
    end
    xlims!(scene, t_lo - gap, t_hi + gap)
    ylims!(scene, t_lo - gap, t_hi + gap)
    if scene isa LAxis
        scene.xlabel = "birth"
        scene.ylabel = persistence ? "persistence" : "death"
    else
        xlabel!(scene, "birth")
        ylabel!(scene, persistence ? "persistence" : "death")
    end

    time_line = lift(time) do t
        if isnothing(t)
            [Point2f0(0, 0)]
        else
            [Point2f0(t_lo - gap, t), Point2f0(t, t), Point2f0(t, t_hi + gap)]
        end
    end
    lines!(scene, time_line; linestyle=:dash)

    return scene
end
plot_diagram(diags; kwargs...) = plot_diagram!(Scene(), diags; kwargs...)

for T in (
    AbstractVector{<:PersistenceDiagram},
    NTuple{<:Any, PersistenceDiagram},
    PersistenceDiagram,
)
    @eval AbstractPlotting.plot(diags::$T; kwargs...) = plot_diagram(diags; kwargs...)
end

@recipe(Bars) do scene
    Theme(
        color = :black,
        ystart = 1,
        linewidth = 3,
        infinity = nothing,
    )
end
function AbstractPlotting.plot!(p::Bars)
    infinity = lift(guess_infinity, p[1], p[:infinity])
    bar_points = lift(p[1], p[:ystart], infinity) do points, ystart, infinity
        res = Point2f0[]
        for (i, p) in enumerate(points)
            y = i - 1 + ystart
            x1, x2 = p
            x2 = isinf(x2) ? infinity : x2
            append!(res, (Point2f0(x1, y), Point2f0(x2, y)))
        end
        if isempty(res)
            [Point2f0(0, 0)]
        else
            res
        end
    end
    linesegments!(p, bar_points, color=p[:color], linewidth=p[:linewidth])
end

function plot_barcode!(
    scene,
    diags;
    infinity=Observable(nothing),
    palette=DEFAULT_PALETTE,
    linewidth=3,
    time=Observable(nothing),
)
    cscheme = PlotUtils.get_colorscheme(palette)
    lims = @lift PersistenceDiagrams.limits(diags, $infinity)
    t_lo, t_hi, inf_val = to_value(lims)
    infinity = @lift $lims[3]
    width = t_hi - t_lo
    gap = width * 0.1
    n_bars = sum(length, diags)
    ygap = n_bars * 0.1

    # Inf line
    lines!(
        scene, [Point2f0(inf_val, 1 - ygap), Point2f0(inf_val, n_bars + ygap)];
        linestyle=:dot, color=:gray,
    )

    ystart = 1
    for diag in diags
        if !isempty(diag)
            color = cscheme[dim(diag) + 1]
            bars!(
                scene, diag;
                linewidth=linewidth,
                color=color,
                ystart=ystart,
                infinity=infinity,
            )
            ystart += length(diag)
        end
    end
    xlims!(scene, t_lo, t_hi)
    ylims!(scene, 0, n_bars)
    if scene isa LAxis
        scene.xlabel = "t"
        scene.ylabel = "i"
    else
        xlabel!(scene, "t")
        ylabel!(scene, "i")
    end

    time_line = lift(time) do t
        if isnothing(t)
            [Point2f0(0,0)]
        else
            [Point2f0(t, 1 - ygap), Point2f0(t, n_bars + ygap)]
        end
    end
    lines!(scene, time_line, linestyle=:dash)

    return scene
end
plot_barcode(diags; kwargs...) = plot_barcode!(Scene(), diags; kwargs...)
