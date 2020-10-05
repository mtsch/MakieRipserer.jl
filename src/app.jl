using AbstractPlotting.MakieLayout

function app(
    points, filtration=Alpha(points);
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
        palette=palette,
        resolution=resolution,
        backgroundcolor=backgroundcolor,
        time=time,
        slider_values=slider_values,
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
    scene, layout = layoutscene(
        outer_padding; resolution=resolution, backgroundcolor=backgroundcolor
    )

    flt_axis = layout[1:2, 1:2] = LScene(scene, title="Filtration")
    dgm_axis = layout[1, 3] = LAxis(scene, title="Diagram")
    bcd_axis = layout[2, 3] = LAxis(scene, title="Barcode")

    min_time = minimum(Ripserer.births(filtration))
    maxis_time = threshold(filtration)

    sld_axis = layout[3, 1:2] = LSlider(
        scene,
        range=range(min_time, maxis_time, length=slider_values),
    )
    set_close_to!(sld_axis, to_value(time))
    on(time) do val
        set_close_to!(sld_axis, val)
    end
    t = sld_axis.value

    title_text = @lift string("t = ", rpad($t, 6)[1:6])
    title = layout[0, :] = LText(scene, title_text, textsize=30)

    plot!(flt_axis, filtration, points; time=t, palette=palette)
    if cameracontrols(flt_axis.scene) isa Camera3D
        cameracontrols(flt_axis.scene).rotationspeed[] = 0.01f0
    end

    plot_diagram!(dgm_axis, diagram; time=t, palette=palette)
    plot_barcode!(bcd_axis, diagram; time=t, palette=palette)

    linkxaxes!(dgm_axis, bcd_axis)
    tightlimits!(dgm_axis)
    tightlimits!(bcd_axis)

    return scene
end
