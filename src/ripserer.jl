using Ripserer:
    BoundaryMatrix, CoboundaryMatrix,
    add!,
    chain_element_type,
    coboundary,
    columns_to_reduce,
    compute_death_simplices!,
    compute_intervals!,
    clear_buffer!,
    dim,
    field_type,
    finalize!,
    initialize_coboundary!,
    is_cohomology,
    is_implicit,
    next_matrix,
    prog_println,
    zeroth_intervals

export ReductionPlot

struct ReductionPlot{
    D, F,
    O1<:ObservableChain, O2<:ObservableChain, O3<:ObservableChain, O4<:ObservableChain,
}
    # Stuff to plot
    data::D
    filtration::F

    # Plots
    scene::Scene
    layout::GridLayout
    stream::Ref{VideoStream}
    data_axis::LScene
    diagram_axis::LScene

    # Plotting data
    chain_a::O1 # current working coboundary
    chain_b::O2 # column to add
    chain_c::O3 # death simplex and pivot
    chain_d::O4 # columns to reduce and cocycles
    intervals::Vector{Observable{Vector{PersistenceInterval}}}

    # Settings
    rotation_speed::Float64
    framerate::Int
    show_diagram::Bool
    show_cocycle::Bool
    birth_frames::Int
    pivot_frames::Int
    column_frames::Int
    cooldown_frames::Int
    debug::Bool

    # Tick tock
    frames::Observable{Int}
end

function ReductionPlot(
    data, filtration=Alpha(data);
    palette=DEFAULT_PALETTE,
    rotation_speed=0.01,
    framerate=30,
    show_diagram=false,
    debug=false,
    show_cocycle=true,
    birth_frames=1,
    pivot_frames=1,
    column_frames=1,
    cooldown_frames=5,
)
    data = convert_arguments(Scatter, data)[1]
    chain_a = ObservableChain(data)
    chain_b = ObservableChain(data)
    chain_c = ObservableChain(data)
    chain_d = ObservableChain(data)
    intervals = Observable{Vector{PersistenceInterval}}[]

    # Set up plots.
    scene, layout = layoutscene()
    stream = Ref(VideoStream(scene; framerate))

    data_axis = layout[1, 1] = LScene(scene)
    plot!(data_axis, data; color=PlotUtils.get_colorscheme(palette)[1])
    plot!(data_axis, chain_a; color=2, palette)
    plot!(data_axis, chain_b; color=3, palette)
    plot!(data_axis, chain_c; color=4, palette)
    plot!(data_axis, chain_d; color=5, palette)

    if show_diagram
        diagram_axis = layout[4, 3] = LAxis(scene)
        if isnothing(infinity)
            infinity = Ripserer.radius(rp.data)
        end
        diagrambackground!(diagram_axis, start, infinity, infinity)
        for ints in intervals
            diagramplot!(diagram_axis, ints)
        end
    else
        # Has to have a value.
        diagram_axis = data_axis
    end

    # The scene needs to be displayed again, or only the last axis created is shown.
    display(scene)

    return ReductionPlot(
        data, filtration,
        scene, layout, stream, data_axis, diagram_axis,
        chain_a, chain_b, chain_c, chain_d, intervals,
        Float64(rotation_speed), framerate, show_diagram, show_cocycle,
        birth_frames, pivot_frames, column_frames, cooldown_frames,
        debug,
        Observable(0),
    )
end

function Base.show(io::IO, plot::ReductionPlot)
    println(io, "ReductionPlot:")
    println(io, " data:            ", summary(plot.data))
    println(io, " filtration:      ", plot.filtration)
    println(io, " frames recorded: ", plot.frames[])
end

function reset!(plot)
    plot.frames[] = 0
    plot.stream[] = VideoStream(plot.scene; framerate=plot.framerate)
    display(plot.scene)
end

function recordframes!(plot, nframes)
    for _ in 1:nframes
        !plot.debug && recordframe!(plot.stream[])
        if cameracontrols(plot.data_axis.scene) isa Camera3D
            rotate_cam!(plot.scene, Vec3(plot.rotationspeed, 0.0, 0.0))
        end
        plot.frames[] += 1
    end
end

"""
    VisualMatrix{M, R<:ReductionPlot, C1, C2}

Wrapper around `CoboundaryMatrix` or `BoundaryMatrix` that also records operations to a
`ReductionPlot`.
"""
struct VisualMatrix{M, R<:ReductionPlot, C1, C2}
    matrix::M
    plot::R
    # Buffers change types so they are stored here.
    buffer::Vector{C1}
    cobuffer::Vector{C2}
end

function VisualMatrix(matrix, plot::ReductionPlot)
    buffer = eltype(matrix.chain)[]
    cobuffer = eltype(matrix.reduced.buffer)[]
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
    elseif k == :data
        return getfield(v, :plot).data
    else
        return getfield(v, k)
    end
end

for f in (:field_type, :dim, :chain_element_type, :is_implicit, :is_cohomology)
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
    matrix.plot.chain_d[] = ()
    matrix.plot.chain_a[] = ()
    matrix.plot.chain_b[] = ()
    matrix.plot.chain_c[] = ()
end

function recordframes!(matrix::VisualMatrix, sym::Symbol)
    recordframes!(matrix.plot, getfield(matrix.plot, sym))
end

function display_birth!(matrix, column_to_reduce)
    clear_plot!(matrix)
    empty!(matrix.buffer)
    empty!(matrix.cobuffer)
    plot = matrix.plot
    plot.chain_d[] = column_to_reduce
    recordframes!(matrix, :birth_frames)
    if !is_cohomology(matrix)
        plot.chain_d[] = ()
    end
end

function display_chain!(matrix)
    buffer = matrix.buffer
    empty!(buffer)
    if !isempty(matrix.chain)
        while (p = pop!(matrix.chain)) ≢ nothing
            push!(buffer, p)
        end
        copy!(matrix.chain.heap, buffer)
    end
    matrix.plot.chain_a[] = buffer
end

function display_pivot!(matrix, pivot)
    matrix.plot.chain_c[] = pivot
    recordframes!(matrix, :pivot_frames)
end

function _sum_dupes!(buffer::Vector{<:AbstractChainElement})
    sort!(buffer)
    curr = buffer[1]
    i = 1
    for j in 2:length(buffer)
        elem = buffer[j]
        if iszero(curr)
            curr = elem
        elseif elem == curr
            curr += elem
        else
            buffer[i] = curr
            curr = elem
            i += 1
        end
    end
    resize!(buffer, i)
end

function display_cocycle!(matrix, column_to_reduce)
    if is_cohomology(matrix) && !isempty(matrix.reduced.buffer)
        cobuffer = matrix.cobuffer
        empty!(cobuffer)
        copy!(cobuffer, matrix.reduced.buffer)
        push!(cobuffer, column_to_reduce)
        _sum_dupes!(cobuffer)
        matrix.plot.chain_d[] = cobuffer
    end
end

function display_column!(matrix, column)
    buffer = matrix.buffer
    empty!(buffer)
    if is_cohomology(matrix)
        for elem in column
            coef = coefficient(elem)
            for cofacet in coboundary(matrix, simplex(elem))
                push!(buffer, chain_element_type(matrix)(cofacet, coef))
            end
        end
        _sum_dupes!(buffer)
    else
        copy!(buffer, column)
    end
    matrix.plot.chain_b[] = buffer
    recordframes!(matrix, :column_frames)
    matrix.plot.chain_b[] = ()
end

function clear_chain!(matrix)
    if is_cohomology(matrix) # in homology, we want to show the final cycle
        matrix.plot.chain_a[] = ()
    end
end

function Ripserer.reduce_column!(matrix::VisualMatrix, column_to_reduce)
    clear_buffer!(matrix.reduced)
    ###
    display_birth!(matrix, column_to_reduce)
    ###

    # Don't do emergent pairs.
    empty!(matrix.chain)
    for cofacet in coboundary(matrix, column_to_reduce)
        push!(matrix.chain, chain_element_type(matrix)(cofacet))
    end
    pivot = pop!(matrix.chain)

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
        display_chain!(matrix)
        display_pivot!(matrix, ())
        ###
        pivot = pop!(matrix.chain)
    end
    if !isnothing(pivot)
        ###
        display_chain!(matrix)
        display_pivot!(matrix, pivot)
        clear_chain!(matrix)
        display_pivot!(matrix, pivot)
        ###
        finalize!(matrix, column_to_reduce, pivot)
    end
    clear_plot!(matrix)

    return pivot
end

function Ripserer.ripserer(
    plot::ReductionPlot,
    dim_max=1,
    modulus=2,
    field_type=Mod{modulus},
    alg=:cohomology
)
    reset!(plot)
    start_time = time_ns()
    zeroth, to_reduce, to_skip = zeroth_intervals(
        plot.filtration, 0, true, field_type, false
    )
    result = _ripserer(Val(alg), plot, zeroth, to_reduce, to_skip, dim_max, field_type)

    # Logging stuff.
    elapsed = round((time_ns() - start_time) / 1e9, digits=3)
    prog_println(true, "Done. Time: ", ProgressMeter.durationstring(elapsed))
    frames = plot.frames[]
    video_length = ProgressMeter.durationstring(frames / plot.framerate)
    fps = round(frames / elapsed, digits=3)
    prog_println(true, "$frames frames recorded at $(fps)fps. Video length: $video_length")
    return result
end

function _ripserer(::Val{:cohomology}, plot, zeroth, to_reduce, to_skip, dim_max, field_type)
    result = PersistenceDiagram[]
    push!(result, zeroth)
    if dim_max > 0
        matrix = CoboundaryMatrix{true}(field_type, plot.filtration, to_reduce, to_skip)
        vmatrix = VisualMatrix(matrix, plot)
        for dim in 1:dim_max
            push!(result, compute_intervals!(vmatrix, 0, true, false))
            recordframes!(plot, plot.cooldown_frames)
            if dim < dim_max
                vmatrix = next_matrix(vmatrix, true)
            end
        end
    end
    return result
end

function _ripserer(::Val{:homology}, plot, zeroth, to_reduce, to_skip, dim_max, field_type)
    result = PersistenceDiagram[]
    push!(result, zeroth)
    filtration = plot.filtration

    if dim_max > 0
        simplices = columns_to_reduce(filtration, Iterators.flatten((to_reduce, to_skip)))
        for dim in 1:dim_max
            matrix = BoundaryMatrix{false}(field_type, filtration, simplices)
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

function _ripserer(::Val{:involuted}, plot, zeroth, to_reduce, to_skip, dim_max, field_type)
    result = PersistenceDiagram[]
    push!(result, zeroth)
    filtration = plot.filtration

    if dim_max > 0
        comatrix = CoboundaryMatrix{true}(field_type, filtration, to_reduce, to_skip)
        for dim in 1:dim_max
            columns, inf_births = compute_death_simplices!(comatrix, true, 0)
            matrix = BoundaryMatrix{false}(field_type, filtration, columns)
            vmatrix = VisualMatrix(matrix, plot)
            diagram = compute_intervals!(vmatrix, 0, true, false)
            recordframes!(plot, plot.cooldown_frames)
            for birth_simplex in inf_births
                push!(
                    diagram.intervals,
                    interval(comatrix, birth_simplex, nothing, 0, _reps(reps, dim))
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
