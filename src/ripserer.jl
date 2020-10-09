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
    O1<:ObservableChain, O2<:ObservableChain, O3<:ObservableChain, O4<:ObservableChain, D
}
    chain_a::O1 # columns to reduce and cocycles
    chain_b::O2 # current working coboundary
    chain_c::O3 # column to add
    chain_d::O4 # death simplex and pivot
    intervals::Vector{Vector{PersistenceInterval}}
    data::D
    scene::Scene
    layout::GridLayout
    stream::VideoStream
end

function ReductionPlot(
    data, intervals, scene::Scene, layout::GridLayout, stream::VideoStream;
    start=0, infinity=nothing
)
    _data = convert_arguments(Scatter, data)[1]
    rp = ReductionPlot(
        ObservableChain(data),
        ObservableChain(data),
        ObservableChain(data),
        ObservableChain(data),
        convert(Vector{Vector{PersistenceInterval}}, intervals),
        _data,
        scene,
        layout,
        stream,
    )
    data_axis = layout[1:3, 1:2] = LScene(scene)
    plot!(data_axis, rp.data)
    plot!(data_axis, rp.chain_a; color=1)
    plot!(data_axis, rp.chain_b; color=2)
    plot!(data_axis, rp.chain_c; color=3)
    plot!(data_axis, rp.chain_d; color=4)

    diagram_axis = layout[2, 3] = LAxis(scene)
    if isnothing(infinity)
        infinity = Ripserer.radius(rp.data)
    end
    diagrambackground!(diagram_axis, start, infinity, infinity)
    for ints in intervals
        diagramplot!(diagram_axis, ints)
    end
    return rp
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
    cobuffer = eltype(matrix.columns_to_reduce)[]
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

#=
function recordframes!(matrix, nframes)
    if !matrix.debug
        for _ in 1:nframes
            recordframe!(matrix.stream)
            if cameracontrols(matrix.scene) isa Camera3D
                rotate_cam!(matrix.scene, Vec3(0.01, 0, 0))
            end
        end
    end
end

function clear!(matrix)
    clear_all!(matrix.plot)
end
function show_chain!(matrix, pivot)
    buffer = matrix.buffer
    empty!(buffer)
    if isempty(matrix.chain)
        return nothing
    end
    while (p = pop!(matrix.chain)) ≢ nothing
        push!(buffer, p)
    end
    copy!(matrix.chain.heap, buffer)

    if !matrix.debug
        clear_chain!(matrix.plot)
        clear_column!(matrix.plot)
        show_chain!(matrix.plot, buffer)
        show_column!(matrix.plot, pivot)
    end
    return nothing
end
function show_cocycle!(matrix, column)
    if is_cohomology(matrix)
        cobuffer = matrix.cobuffer
        empty!(cobuffer)
        for sx in matrix.reduced.buffer
            push!(cobuffer, simplex(sx))
        end
        push!(cobuffer, column)
        if !matrix.debug
            show_birth!(matrix.plot, cobuffer)
        end
    end
end
function show_birth!(matrix, sx)
    if !matrix.debug
        show_birth!(matrix.plot, sx)
    end
end
function show_death!(matrix, pivot; nframes=1)
    if !matrix.debug
        clear_column!(matrix.plot)
        show_death!(matrix.plot, pivot)
        if !is_cohomology(matrix)
            show_chain!(matrix, pivot)
        end
    end
end
=#

function Ripserer.reduce_column!(matrix::VisualMatrix, column_to_reduce)
    clear_buffer!(matrix.reduced)
  # ###
  # clear!(matrix)
  # show_birth!(matrix, column_to_reduce)
  # recordframes!(matrix, 1)
  # if !is_cohomology(matrix)
  #     clear_birth!(matrix.plot)
  # end
  # ###

    pivot = initialize_coboundary!(matrix, column_to_reduce)

    while !isnothing(pivot)
        column = matrix.reduced[pivot]
        isempty(column) && break

  #     ###
  #     show_chain!(matrix, pivot)
  #     recordframes!(matrix, 1)
  #     ###
        add!(matrix, column, pivot)
  #     ###
  #     show_cocycle!(matrix, column_to_reduce)
  #     show_chain!(matrix, pivot)
  #     recordframes!(matrix, 1)
  #     ###
        pivot = pop!(matrix.chain)
    end
    if !isnothing(pivot)
  #     ###
  #     show_death!(matrix, pivot)
  #     recordframes!(matrix, 1)
  #     ###
        finalize!(matrix, column_to_reduce, pivot)
    end

    return pivot
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
)
    if isnothing(scene) || isnothing(layout)
        scene, layout = layoutscene()
    end
    zeroth, to_reduce, to_skip = zeroth_intervals(
        filtration, 0, true, field_type, false
    )
    stream = VideoStream(scene; framerate)
    plot = ReductionPlot(data, [zeroth], scene, layout, stream)
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
            diagram = compute_intervals!(matrix, 0, true, false)
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
