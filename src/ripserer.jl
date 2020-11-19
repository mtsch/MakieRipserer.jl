using Ripserer:
    BoundaryMatrix,
    CoboundaryMatrix,
    add!,
    clean!,
    coboundary,
    columns_to_reduce,
    compute_death_simplices!,
    compute_intervals!,
    dim,
    ordering,
    finalize!,
    heapmove!,
    heappop!,
    heappush!,
    is_cohomology,
    next_matrix,
    @prog_println,
    zeroth_intervals

export ReductionPlot

struct ReductionPlot{
    D,
    F,
    L,
    O1<:ObservableChain,
    O2<:ObservableChain,
    O3<:ObservableChain,
    O4<:ObservableChain,
}
    # Stuff to plot
    data::D
    filtration::F

    # Plots
    scene::Scene
    layout::GridLayout
    stream::Ref{Union{VideoStream,Nothing}}
    data_axis::LScene
    diagram_axis::L

    # Plotting data
    chain_a::O1 # current working coboundary
    chain_b::O2 # column to add
    chain_c::O3 # death simplex and pivot
    chain_d::O4 # columns to reduce and cocycles
    diagram::ObservableDiagram

    # Settings
    rotation_speed::Float64
    framerate::Int
    show_diagram::Bool
    show_cocycles::Bool
    birth_frames::Int
    pivot_frames::Int
    column_frames::Int
    cooldown_frames::Int
    debug::Bool

    # Number of recorded frames. Can be listened to with `on`.
    frames::Observable{Int}
end

function ReductionPlot(
    data,
    filtration = Alpha(data);
    palette = DEFAULT_PALETTE,
    rotation_speed = 0.01,
    framerate = 30,
    show_diagram = false,
    debug = false,
    show_cocycles = true,
    birth_frames = 1,
    pivot_frames = 1,
    column_frames = 1,
    cooldown_frames = 5,
)
    data = convert_arguments(Scatter, data)[1]
    chain_a = ObservableChain(data)
    chain_b = ObservableChain(data)
    chain_c = ObservableChain(data)
    chain_d = ObservableChain(data)

    t_min = minimum(Ripserer.births(filtration))
    t_max = threshold(filtration)
    if isnothing(t_max) || !isfinite(t_max)
        t_max = Ripserer.radius(data)
    end
    diagram = ObservableDiagram(t_min, t_max)

    # Set up plots.
    scene, layout = layoutscene()
    stream = Ref{Union{VideoStream,Nothing}}(nothing)
    if !debug
        stream[] = VideoStream(scene; framerate)
    end

    data_axis = layout[1:2, 1:2] = LScene(scene; title = "Data")
    plot!(data_axis, data; color = PlotUtils.get_colorscheme(palette)[1])
    plot!(data_axis, chain_a; color = 2, palette)
    plot!(data_axis, chain_b; color = 3, palette)
    plot!(data_axis, chain_c; color = 4, palette)
    plot!(data_axis, chain_d; color = 5, palette)

    if show_diagram
        diagram_axis = layout[1:2, 3] = LAxis(scene; title = "Diagram")
        plot!(diagram_axis, diagram)
        xlims!(diagram_axis, t_min, t_max)
        ylims!(diagram_axis, t_min, t_max)
        tightlimits!(diagram_axis)
    else
        diagram_axis = nothing
    end

    # The scene needs to be displayed again, or only the last axis created is shown.
    !debug && display(scene)

    return ReductionPlot(
        data,
        filtration,
        scene,
        layout,
        stream,
        data_axis,
        diagram_axis,
        chain_a,
        chain_b,
        chain_c,
        chain_d,
        diagram,
        Float64(rotation_speed),
        framerate,
        show_diagram,
        show_cocycles,
        birth_frames,
        pivot_frames,
        column_frames,
        cooldown_frames,
        debug,
        Observable(0),
    )
end

function Base.show(io::IO, plot::ReductionPlot)
    !plot.debug && display(plot.scene)
    println(io, "ReductionPlot:")
    println(io, " data:            ", summary(plot.data))
    println(io, " filtration:      ", plot.filtration)
    println(io, " frames recorded: ", plot.frames[])
end

function Base.empty!(plot)
    plot.frames[] = 0
    if !plot.debug
        plot.stream[] = VideoStream(plot.scene; framerate = plot.framerate)
    else
        plot.stream[] = nothing
    end
    plot.chain_a[] = ()
    plot.chain_b[] = ()
    plot.chain_c[] = ()
    plot.chain_d[] = ()

    if plot.show_diagram
        empty!(plot.diagram)
        empty!(plot.diagram_axis.scene.plots)
        start = minimum(Ripserer.births(plot.filtration))
        thresh = threshold(plot.filtration)
        if isnothing(thresh) || !isfinite(thresh)
            thresh = Ripserer.radius(plot.data)
        end
        diagrambackground!(plot.diagram_axis, start, thresh, thresh)
    end
    return plot
end

function AbstractPlotting.save(filename, plot::ReductionPlot; kwargs...)
    save(filename, plot.stream[]; kwargs...)
end

function recordframes!(plot, nframes)
    for _ = 1:nframes
        !plot.debug && recordframe!(plot.stream[])
        if cameracontrols(plot.data_axis.scene) isa Camera3D
            rotate_cam!(plot.data_axis.scene, Vec3(plot.rotation_speed, 0.0, 0.0))
        end
        plot.frames[] += 1
    end
end

"""
    VisualMatrix{M, R<:ReductionPlot, C1, C2}

Wrapper around `CoboundaryMatrix` or `BoundaryMatrix` that also records operations to a
`ReductionPlot`.
"""
struct VisualMatrix{M,R<:ReductionPlot,C1,C2}
    matrix::M
    plot::R
    # Buffers change types so they are stored here.
    _buffer::C1
    _cobuffer::C2
end

function VisualMatrix(matrix, plot::ReductionPlot)
    buffer = copy(matrix.chain)
    cobuffer = copy(matrix.buffer)
    return VisualMatrix(matrix, plot, buffer, cobuffer)
end

# Make it pretend it's a (co)boundary matrix.
function Base.getproperty(v::VisualMatrix, k::Symbol)
    if k == :filtration
        return getfield(v, :matrix).filtration
    elseif k == :reduced
        return getfield(v, :matrix).reduced
    elseif k == :chain
        return getfield(v, :matrix).chain
    elseif k == :columns_to_reduce
        return getfield(v, :matrix).columns_to_reduce
    elseif k == :columns_to_skip
        return getfield(v, :matrix).columns_to_skip
    elseif k == :buffer
        return getfield(v, :matrix).buffer
    elseif k == :data
        return getfield(v, :plot).data
    else
        return getfield(v, k)
    end
end

for f in (:dim, :is_implicit, :is_cohomology, :ordering, :field_type)
    @eval begin
        Ripserer.$f(v::VisualMatrix) = Ripserer.$f(v.matrix)
    end
end

function Ripserer.coboundary(matrix::VisualMatrix, simplex::AbstractSimplex)
    coboundary(matrix.matrix, simplex)
end

function Ripserer.next_matrix(matrix::VisualMatrix, progress)
    next = next_matrix(matrix.matrix, progress)
    return VisualMatrix(next, matrix.plot)
end

function clear_plot!(matrix)
    matrix.plot.chain_a[] = ()
    matrix.plot.chain_b[] = ()
    matrix.plot.chain_c[] = ()
    matrix.plot.chain_d[] = ()
    if matrix.plot.show_diagram
        diagram = matrix.plot.diagram
        b, d = diagram.intervals[][end]
        b == d && pop!(diagram)
    end
end

function recordframes!(matrix::VisualMatrix, sym::Symbol)
    recordframes!(matrix.plot, getfield(matrix.plot, sym))
end

function display_birth!(matrix, column_to_reduce)
    clear_plot!(matrix)
    empty!(matrix._buffer)
    empty!(matrix._cobuffer)
    plot = matrix.plot
    plot.chain_d[] = column_to_reduce

    if plot.show_diagram
        if is_cohomology(matrix)
            push!(plot.diagram, (birth(column_to_reduce), Inf), dim(matrix) + 1)
        else
            push!(plot.diagram, (0, birth(column_to_reduce)), dim(matrix) + 1)
        end
    end

    recordframes!(matrix, :birth_frames)
    if !is_cohomology(matrix)
        plot.chain_d[] = ()
    end
end

function display_chain!(matrix)
    buffer = matrix._buffer
    empty!(buffer)
    heapmove!(buffer, matrix.chain, ordering(matrix))
    copy!(matrix.chain, buffer)
    matrix.plot.chain_a[] = buffer
end

function display_pivot!(matrix, pivot)
    plot = matrix.plot
    plot.chain_c[] = pivot
    if plot.show_diagram && pivot != ()
        curr_b, curr_d = plot.diagram.intervals[][end]
        if is_cohomology(matrix)
            edit_last!(plot.diagram, (curr_b, birth(pivot)))
        else
            edit_last!(plot.diagram, (birth(pivot), curr_d))
        end
    end
    recordframes!(matrix, :pivot_frames)
end

function display_cocycle!(matrix, column_to_reduce)
    if is_cohomology(matrix) && !isempty(matrix.buffer) && matrix.plot.show_cocycles
        cobuffer = matrix._cobuffer
        empty!(cobuffer)
        copy!(cobuffer, matrix.buffer)
        push!(cobuffer, column_to_reduce)
        clean!(cobuffer, ordering(matrix))
        matrix.plot.chain_d[] = cobuffer
    end
end

function display_column!(matrix, column)
    buffer = matrix._buffer
    empty!(buffer)
    if is_cohomology(matrix)
        for elem in column
            coef = coefficient(elem)
            for cofacet in coboundary(matrix, simplex(elem))
                push!(buffer, (cofacet, coef))
            end
        end
        clean!(buffer, ordering(matrix))
    else
        copy!(buffer, column)
    end
    matrix.plot.chain_b[] = buffer
    #recordframes!(matrix, :column_frames)
    #matrix.plot.chain_b[] = ()
end

function display_reduced!(matrix, column_to_reduce)
    plot = matrix.plot
    if plot.show_diagram
        if is_cohomology(matrix)
            edit_last!(plot.diagram, (birth(column_to_reduce), Inf))
        else
            pop!(plot.diagram)
        end
    end
    recordframes!(matrix, :pivot_frames)
end

function clear_chain!(matrix)
    if is_cohomology(matrix) # in homology, we want to show the final cycle
        matrix.plot.chain_a[] = ()
    end
end
function clear_column!(matrix)
    matrix.plot.chain_b[] = ()
end

function Ripserer.reduce_column!(matrix::VisualMatrix, column_to_reduce)
    empty!(matrix.buffer)
    ###
    display_birth!(matrix, column_to_reduce)
    ###

    # Don't do emergent pairs.
    empty!(matrix.chain)
    for cofacet in coboundary(matrix, column_to_reduce)
        heappush!(matrix.chain, cofacet, ordering(matrix))
    end
    pivot = heappop!(matrix.chain, ordering(matrix))

    while !isnothing(pivot)
        ###
        display_chain!(matrix)
        display_pivot!(matrix, pivot)
        ###
        column = matrix.reduced[pivot]
        isempty(column) && break
        add!(matrix, column, pivot)
        ###
        display_cocycle!(matrix, column_to_reduce)
        display_column!(matrix, column)
        display_pivot!(matrix, pivot)
        clear_column!(matrix)
        display_chain!(matrix)
        display_pivot!(matrix, ())
        ###
        pivot = heappop!(matrix.chain, ordering(matrix))
    end
    if !isnothing(pivot)
        ###
        display_chain!(matrix)
        display_pivot!(matrix, pivot)
        if is_cohomology(matrix)
            clear_chain!(matrix)
            display_pivot!(matrix, pivot)
        end
        ###
        finalize!(matrix, column_to_reduce, pivot)
    else
        display_reduced!(matrix, pivot)
    end
    clear_plot!(matrix)

    return pivot
end

function Ripserer.ripserer(
    plot::ReductionPlot;
    dim_max = 1,
    modulus = 2,
    field = Mod{modulus},
    alg = :cohomology,
)
    empty!(plot)
    !plot.debug && display(plot.stream)
    start_time = time_ns()
    zeroth, to_reduce, to_skip = zeroth_intervals(plot.filtration, 0, true, field, false)
    append!(plot.diagram, zeroth)
    result = _ripserer(Val(alg), plot, zeroth, to_reduce, to_skip, dim_max, field)

    # Logging stuff.
    elapsed = round((time_ns() - start_time) / 1e9, digits = 3)
    @prog_println true "Done. Time: " ProgressMeter.durationstring(elapsed)
    frames = plot.frames[]
    video_length = ProgressMeter.durationstring(frames / plot.framerate)
    fps = round(frames / elapsed, digits = 3)
    @prog_println true "$frames frames recorded at $(fps)fps. Video length: $video_length"
    return result
end

function _ripserer(::Val{:cohomology}, plot, zeroth, to_reduce, to_skip, dim_max, field)
    result = PersistenceDiagram[]
    push!(result, zeroth)
    if dim_max > 0
        matrix = CoboundaryMatrix{true}(field, plot.filtration, to_reduce, to_skip)
        vmatrix = VisualMatrix(matrix, plot)
        for dim = 1:dim_max
            push!(result, compute_intervals!(vmatrix, 0, true, false))
            recordframes!(plot, plot.cooldown_frames)
            if dim < dim_max
                vmatrix = next_matrix(vmatrix, true)
            end
        end
    end
    return result
end

function _ripserer(::Val{:homology}, plot, zeroth, to_reduce, to_skip, dim_max, field)
    result = PersistenceDiagram[]
    push!(result, zeroth)
    filtration = plot.filtration

    if dim_max > 0
        simplices = columns_to_reduce(filtration, Iterators.flatten((to_reduce, to_skip)))
        for dim = 1:dim_max
            matrix = BoundaryMatrix{false}(field, filtration, simplices)
            vmatrix = VisualMatrix(matrix, plot)
            push!(result, compute_intervals!(vmatrix, 0, true, false))
            recordframes!(plot, plot.cooldown_frames)
            if dim < dim_max
                simplices = columns_to_reduce(filtration, simplices)
            end
        end
    end

    return result
end

function _ripserer(::Val{:involuted}, plot, zeroth, to_reduce, to_skip, dim_max, field)
    result = PersistenceDiagram[]
    push!(result, zeroth)
    filtration = plot.filtration

    if dim_max > 0
        comatrix = CoboundaryMatrix{true}(field, filtration, to_reduce, to_skip)
        for dim = 1:dim_max
            columns, inf_births = compute_death_simplices!(comatrix, true, 0)
            matrix = BoundaryMatrix{false}(field, filtration, columns)
            vmatrix = VisualMatrix(matrix, plot)
            diagram = compute_intervals!(vmatrix, 0, true, false)
            recordframes!(plot, plot.cooldown_frames)
            for birth_simplex in inf_births
                push!(
                    diagram.intervals,
                    interval(comatrix, birth_simplex, nothing, 0, _reps(reps, dim)),
                )
            end
            push!(result, diagram)
            if dim < dim_max
                comatrix = next_matrix(comatrix, true)
            end
        end
    end
    return result
end
