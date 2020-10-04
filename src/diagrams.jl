function guess_infinity(diagram, infinity)
    if isnothing(infinity)
        thresh = threshold(diagram)
        if isnothing(thresh) || ismissing(thresh) || isinf(thresh)
            return 1.1 * maximum(Iterators.filter(isfinite, Iterators.flatten(points)))
        else
            return thresh
        end
    else
        return infinity
    end
end

@recipe(DiagramPlot, diagram) do scene
    return Theme(
        color = :gray,
        infinity = nothing,
        persistence = false,
    )
end

function AbstractPlotting.default_theme(
    scene::SceneLike, ::Type{<:Plot(PersistenceDiagram)}
)
    return Theme(
        color = :gray,
        infinity = nothing,
        persistence = false,
    )
end
function AbstractPlotting.plot!(p::DiagramPlot)
    infinity = lift(guess_infinity, p[1], p[:infinity])
    points = lift(p[1], p[:persistence], infinity) do diag, pers, inf
        pts = Vector{Point2f0}(undef, length(diag))
        for i in eachindex(diag)
            b = birth(diag[i])
            d = min(inf, pers ? persistence(diag[i]) : death(diag[i]))
            pts[i] = Point2f0(b, d)
        end
        pts
    end
    scatter!(p, points; color=p[:color])
end
AbstractPlotting.plottype(::PersistenceDiagram) = DiagramPlot

function plot_diagram!(
    scene,
    diags;
    infinity=Observable(nothing),
    persistence=false,
    palette=DEFAULT_PALETTE,
    time=Observable(nothing),
)
    cscheme = colorschemes[palette]
    lims = @lift PersistenceDiagrams.limits(diags, $infinity)
    t_lo, t_hi, inf_val = to_value(lims)
    infinity = @lift $lims[3]
    width = t_hi - t_lo
    gap = width * 0.1

    # Zero persistence line
    if persistence
        lines!(
            scene, [Point2f0(t_lo - gap, 0), Point2f0(t_hi + gap, 0)]
        )
    else
        lines!(
            scene, [Point2f0(t_lo - gap, t_lo - gap), Point2f0(t_hi + gap, t_hi + gap)]
        )
    end

    # Inf line
    lines!(
        scene, [Point2f0(t_lo - gap, inf_val), Point2f0(t_hi + gap, inf_val)];
        linestyle=:dot, color=:gray,
    )
    for (i, diag) in enumerate(diags)
        !isempty(diag) && plot!(scene, diag; infinity, persistence, color=cscheme[i])
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
    lines!(scene, time_line, linestyle=:dash)

    return scene
end
plot_diagram(diags; kwargs...) = plot_diagram!(Scene(), diags; kwargs...)

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
    cscheme = colorschemes[palette]
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
            bars!(scene, diag; linewidth, color, ystart, infinity)
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
