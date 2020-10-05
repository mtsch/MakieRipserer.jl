using AbstractPlotting.MakieLayout

function app(
    points, filtration=Rips(points);
    palette=DEFAULT_PALETTE,
    resolution=(1600, 900),
    backgroundcolor=:white,
    time=Observable(0.0),
    slider_values=1000,
    ripserer_kwargs...
)
    @info "computing diagrams"
    diagram = ripserer(filtration; progress=true, ripserer_kwargs...)
    return app(
        points, filtration, diagram;
        palette=DEFAULT_PALETTE,
        resolution=(1600, 900),
        backgroundcolor=:white,
        time=Observable(0.0),
        slider_values=1000
    )
end

function app(
    points, filtration, diagram;
    palette=DEFAULT_PALETTE,
    resolution=(1600, 900),
    backgroundcolor=:white,
    time=Observable(0.0),
    slider_values=1000,
)
    outer_padding = 20
    scene, layout = layoutscene(outer_padding; resolution, backgroundcolor)

    flt_ax = layout[1:2, 1:2] = LScene(scene, title="Filtration")
    dgm_ax = layout[1, 3] = LAxis(scene, title="Diagram")
    bcd_ax = layout[2, 3] = LAxis(scene, title="Barcode")

    min_time = minimum(Ripserer.births(filtration))
    max_time = threshold(filtration)

    sld_ax = layout[3, 1:2] = LSlider(
        scene,
        range=range(min_time, max_time, length=slider_values),
    )
    set_close_to!(sld_ax, to_value(time))
    on(time) do val
        set_close_to!(sld_ax, val)
    end
    t = sld_ax.value

    title_text = @lift string("t = ", rpad($t, 6)[1:6])
    title = layout[0, :] = LText(scene, title_text, textsize=30)

    plot!(flt_ax, filtration, points; time=t, palette)
    if cameracontrols(flt_ax.scene) isa Camera3D
        cameracontrols(flt_ax.scene).rotationspeed[] = 0.01f0
    end

    plot_diagram!(dgm_ax, diagram; time=t, palette)
    plot_barcode!(bcd_ax, diagram; time=t, palette)

    linkxaxes!(dgm_ax, bcd_ax)
    tightlimits!(dgm_ax)
    tightlimits!(bcd_ax)

    return scene
end

function movie(points, filtration=Rips(points);
               palette=DEFAULT_PALETTE,
               resolution=(1600, 900),
               backgroundcolor=:white,
               t_start=minimum(Ripserer.births.(filtration)),
               t_end=threshold(filtration),
               n_steps=1000,
               fps=30,
               filename="out.mkv",
               ripserer_kwargs...)
    time = Observable(t_start)
    scene = app(
        points, filtration; palette, resolution, backgroundcolor, time, ripserer_kwargs...
    )
    r = range(t_start, t_end, length=n_steps)
    record(scene, filename, r; framerate=fps) do t
        println("t = $t / $t_end")
        time[] = t
    end
end
