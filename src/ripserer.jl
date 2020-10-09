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
    initialize_coboundary!,
    is_cohomology,
    is_implicit,
    finalize!,
    next_matrix,
    zeroth_intervals

struct ReductionPlot{
    O1<:ObservableChain, O2<:ObservableChain, O3<:ObservableChain, O4<:ObservableChain,
    D, C<:AbstractCamera
}
    chain_a::O1 # current working coboundary
    chain_b::O2 # column to add
    chain_c::O3 # death simplex and pivot
    chain_d::O4 # columns to reduce and cocycles
    intervals::Vector{Vector{PersistenceInterval}}
    data::D
    scene::Scene
    layout::GridLayout
    stream::VideoStream
    camera::C
    rotationspeed::Float64
end

function ReductionPlot(
    data, intervals, scene::Scene, layout::GridLayout, stream::VideoStream;
    start=0, infinity=nothing, palette=DEFAULT_PALETTE, rotationspeed=0.01
)
    _data = convert_arguments(Scatter, data)[1]
    chain_a = ObservableChain(data)
    chain_b = ObservableChain(data)
    chain_c = ObservableChain(data)
    chain_d = ObservableChain(data)

    data_axis = scene #layout[1:3, 1:2] = LScene(scene) # when diagram will be shown
    plot!(data_axis, _data; color=PlotUtils.get_colorscheme(palette)[1])
    plot!(data_axis, chain_a; color=2)
    plot!(data_axis, chain_b; color=3)
    plot!(data_axis, chain_c; color=4)
    plot!(data_axis, chain_d; color=5)
    camera = cameracontrols(data_axis)

    intervals = convert(Vector{Vector{PersistenceInterval}}, intervals)

    #= TODO also show diagram as it's being constructed
    diagram_axis = layout[2, 3] = LAxis(scene)
    if isnothing(infinity)
        infinity = Ripserer.radius(rp.data)
    end
    diagrambackground!(diagram_axis, start, infinity, infinity)
    for ints in intervals
        diagramplot!(diagram_axis, ints)
    end
    =#

    rp = ReductionPlot(
        chain_a, chain_b, chain_c, chain_d,
        intervals, _data, scene, layout, stream, camera, rotationspeed
    )
    return rp
end

function recordframes!(plot, nframes)
    for _ in 1:nframes
        recordframe!(plot.stream)
        if plot.camera isa Camera3D
            rotate_cam!(plot.scene, Vec3(plot.rotationspeed, 0.0, 0.0))
        end
    end
end

"""
    VisualMatrix{M, R<:ReductionPlot, C1, C2, NT<:NamedTuple}

Wrapper around `CoboundaryMatrix` or `BoundaryMatrix` that also records operations to a
stream.
"""
struct VisualMatrix{M, R<:ReductionPlot, C1, C2, NT<:NamedTuple}
    matrix::M

    plot::R

    buffer::Vector{C1}
    cobuffer::Vector{C2}

    debug::Bool
    kwargs::NT
end

function VisualMatrix(matrix, plot::ReductionPlot; debug::Bool, kwargs...)
    buffer = eltype(matrix.chain)[]
    cobuffer = eltype(matrix.reduced.buffer)[]
    return VisualMatrix(matrix, plot, buffer, cobuffer, debug, (;kwargs...))
end

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
    elseif k == :scene
        return getfield(v, :plot).scene
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
    return VisualMatrix(next, matrix.plot; debug=matrix.debug, matrix.kwargs...)
end

function clear_plot!(matrix)
    matrix.plot.chain_d[] = ()
    matrix.plot.chain_a[] = ()
    matrix.plot.chain_b[] = ()
    matrix.plot.chain_c[] = ()
end

function recordframes!(matrix::VisualMatrix, n)
    if !matrix.debug
        recordframes!(matrix.plot, n)
    end
end

function display_birth!(matrix, column_to_reduce)
    clear_plot!(matrix)
    empty!(matrix.buffer)
    empty!(matrix.cobuffer)
    plot = matrix.plot
    plot.chain_d[] = column_to_reduce
    recordframes!(matrix, get(matrix.kwargs, :birth_frames, 2))
    if !is_cohomology(matrix)
        plot.chain_d[] = ()
    end
    return nothing
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
    #recordframes!(matrix, get(matrix.kwargs, :chain_frames, 1))
    return nothing
end

function display_pivot!(matrix, pivot)
    matrix.plot.chain_c[] = pivot
    recordframes!(matrix, get(matrix.kwargs, :pivot_frames, 1))
    return nothing
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
    return nothing
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
    return nothing
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
    recordframes!(matrix, get(matrix.kwargs, :column_frames, 1))
    matrix.plot.chain_b[] = ()
    return nothing
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
        ###
        finalize!(matrix, column_to_reduce, pivot)
    end
    clear_plot!(matrix)

    return pivot
end

function compute_intervals!(matrix)
    intervals = compute_intervals!(matrix.matrix, 0, true, false)
    recordframes!(matrix, get(matrix.kwargs, :frames_after, 5))
    return intervals
end

function vis_ripserer(
    data,
    filtration=Alpha(data);
    scene=nothing,
    layout=nothing,
    dim_max=1,
    modulus=2,
    field_type=Mod{modulus},
    alg=:cohomology,
    debug=false,
    framerate=6,
    rotationspeed=0.01,
)
    if isnothing(scene)
        scene, layout = layoutscene()
    elseif isnothing(layout)
        layout = GridLayout()
    end
    zeroth, to_reduce, to_skip = zeroth_intervals(
        filtration, 0, true, field_type, false
    )
    stream = VideoStream(scene; framerate)
    plot = ReductionPlot(data, [zeroth], scene, layout, stream; rotationspeed)
    return vis_ripserer(
        Val(alg), filtration, zeroth, to_reduce, to_skip, plot;
        dim_max, field_type, debug
    )
end

function vis_ripserer(
    ::Val{:cohomology}, filtration, zeroth, to_reduce, to_skip, plot;
    dim_max, field_type, debug, kwargs...
)
    result = PersistenceDiagram[]
    push!(result, zeroth)
    if dim_max > 0
        matrix = CoboundaryMatrix{true}(field_type, filtration, to_reduce, to_skip)
        vmatrix = VisualMatrix(matrix, plot; debug, kwargs...)
        for dim in 1:dim_max
            push!(result, compute_intervals!(vmatrix, 0, true, false))
            if dim < dim_max
                vmatrix = next_matrix(vmatrix, true)
            end
        end
    end
    return result, plot.stream
end

function vis_ripserer(
    ::Val{:homology}, filtration, zeroth, to_reduce, to_skip, plot;
    dim_max, field_type, debug, kwargs...
)
    result = PersistenceDiagram[]
    push!(result, zeroth)

    if dim_max > 0
        simplices = columns_to_reduce(filtration, Iterators.flatten((to_reduce, to_skip)))
        for dim in 1:dim_max
            matrix = BoundaryMatrix{false}(field_type, filtration, simplices)
            vmatrix = VisualMatrix(matrix, plot; debug, kwargs...)
            push!(result, compute_intervals!(vmatrix, 0, true, false))
            if dim < dim_max
                simplices = columns_to_reduce(filtration, simplices)
            end
        end
    end

    return result, plot.stream
end

function vis_ripserer(
    ::Val{:involuted}, filtration, zeroth, to_reduce, to_skip, plot;
    dim_max, field_type, debug, kwargs...
)
    result = PersistenceDiagram[]
    push!(result, zeroth)

    if dim_max > 0
        comatrix = CoboundaryMatrix{true}(field_type, filtration, to_reduce, to_skip)
        for dim in 1:dim_max
            columns, inf_births = compute_death_simplices!(comatrix, true, 0)
            matrix = BoundaryMatrix{false}(field_type, filtration, columns)
            vmatrix = VisualMatrix(matrix, plot; debug, kwargs...)
            diagram = compute_intervals!(vmatrix, 0, true, false)
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
    return result, plot.stream
end

export vis_ripserer
