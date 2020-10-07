using AbstractPlotting.MakieLayout

function app(
    points, filtration=Alpha(points);
    palette=DEFAULT_PALETTE,
    resolution=(1600, 900),
    backgroundcolor=:white,
    time=Observable(0.0),
    slider_values=1000,
    dim_max=1,
    ripserer_kwargs...
)
    @info "computing diagrams"
    diagram = ripserer(filtration; progress=true, ripserer_kwargs..., dim_max=dim_max)
    return app(
        points, filtration, diagram;
        palette=palette,
        resolution=resolution,
        backgroundcolor=backgroundcolor,
        time=time,
        slider_values=slider_values,
        dim_max=dim_max,
    )
end

function app(
    points, filtration, diagram;
    palette=DEFAULT_PALETTE,
    resolution=(1600, 900),
    backgroundcolor=:white,
    time=Observable(0.0),
    slider_values=1000,
    dim_max=1,
)
    outer_padding = 20
    scene, layout = layoutscene(
        outer_padding; resolution=resolution, backgroundcolor=backgroundcolor
    )

    filtration_axis = layout[1:2, 1:2] = LScene(scene, title="Filtration")
    diagram_axis = layout[1, 3] = LAxis(scene, title="Diagram")
    bcd_axis = layout[2, 3] = LAxis(scene, title="Barcode")

    min_time = minimum(Ripserer.births(filtration))
    max_time = threshold(filtration)

    time_slider, t = time_slider!(scene, min_time, max_time, slider_values, time)
    toggles, triangles, edges, criticals = toggles!(scene, dim_max)
    triangles = @lift $triangles && $edges
    layout[3, 1:2] = time_slider
    layout[3, 3] = toggles

    plot!(
        filtration_axis, filtration, points;
        time=t, palette=palette, triangles=triangles, edges=edges, markersize=10
    )
    plot_critical_chains!(filtration_axis, diagram, points, criticals, t, palette)
    if cameracontrols(filtration_axis.scene) isa Camera3D
        cameracontrols(filtration_axis.scene).rotationspeed[] = 0.01f0
    end

    plot_diagram!(diagram_axis, diagram; time=t, palette=palette)
    plot_barcode!(bcd_axis, diagram; time=t, palette=palette)

    linkxaxes!(diagram_axis, bcd_axis)
    tightlimits!(diagram_axis)
    tightlimits!(bcd_axis)

    return scene
end

function time_slider!(scene, min_time, max_time, slider_values, time)
    time_slider = LSlider(
        scene; range=range(min_time, max_time; length=slider_values)
    )
    time_str = @lift string("t=", round($(time_slider.value); digits=3))
    time_label = LText(scene, time_str; tellwidth=false)
    set_close_to!(time_slider, to_value(time))
    on(time) do t
        set_close_to!(time_slider, t)
    end
    return grid!(reshape([time_label, time_slider], (2, 1)), tellwidth=false), time_slider.value
end

function toggles!(scene, dim_max)
    triangle_toggle = LToggle(scene; active=true, tellwidth=false)
    triangle_label = LText(scene, "triangles"; tellwidth=false)
    edge_toggle = LToggle(scene; active=true, tellwidth=false)
    edge_label = LText(scene, "edges"; tellwidth=false)
    critical_toggles = [LToggle(scene; active=false, tellwidth=false) for d in 0:dim_max]
    critical_labels = [LText(scene, "$d-critical simplices"; tellwidth=false) for d in 0:dim_max]

    layout = [
        triangle_toggle triangle_label;
        edge_toggle edge_label;
        critical_toggles critical_labels;
    ]
    return (
        grid!(layout),
        triangle_toggle.active,
        edge_toggle.active,
        [t.active for t in critical_toggles],
    )
end

function plot_critical_chains!(scene, diagram, points, criticals, time, palette)
    death_chains = [FilteredChain(filter(!isnothing, death_simplex.(d)), points)
                    for d in diagram]
    birth_chains = [FilteredChain(birth_simplex.(d), points)
                    for d in diagram]
    crit_ts = [@lift $(criticals[i]) ? $time : -Inf for i in eachindex(diagram)]
    for (birth_chain, death_chain, time, i) in zip(
        birth_chains, death_chains, crit_ts, eachindex(crit_ts)
    )
        for chain in (birth_chain, death_chain)
            if length(chain.triangles) == 0
                chainplot!(scene, chain; time, palette, edgecolor=2+i, linewidth=3)
            else
                chainplot!(scene, chain; time, palette, trianglecolor=2+i)
            end
        end
    end
end
