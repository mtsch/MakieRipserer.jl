struct ReductionPlot{O1<:ObservableChain,O2<:ObservableChain,O3<:ObservableChain,D}
    chain::O1
    column::O1
    birth_simplex::O2
    death_simplex::O3
    data::D
    scene::Scene
end

using ProgressMeter
using Ripserer:
    clear_buffer!,
    initialize_coboundary!,
    add!,
    finalize!,
    compute_intervals!,
    coboundary,
    zeroth_intervals,
    next_matrix,
    CoboundaryMatrix,
    is_implicit,
    is_cohomology,
    columns_to_reduce,
    BoundaryMatrix

struct VisualMatrix{M,R<:ReductionPlot,S,C1,C2,NT<:NamedTuple}
    matrix::M

    plot::R
    stream::S

    buffer::Vector{C1}
    cobuffer::Vector{C2}

    debug::Bool
    kwargs::NT
end

function VisualMatrix(matrix, scene::Scene, stream, data, debug::Bool; kwargs...)
    plot = ReductionPlot(
        eltype(matrix.chain)[],
        eltype(matrix.chain)[],
        eltype(matrix.columns_to_reduce)[],
        eltype(matrix.chain)[],
        data,
        scene,
    )
    buffer = eltype(matrix.chain)[]
    cobuffer = eltype(matrix.columns_to_reduce)[]
    vmatrix = VisualMatrix(matrix, plot, stream, buffer, cobuffer, debug, (; kwargs...))
    return vmatrix
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

using Ripserer: field_type, dim, chain_element_type

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
    return VisualMatrix(
        next,
        matrix.scene,
        matrix.stream,
        matrix.data,
        matrix.debug;
        matrix.kwargs...,
    )
end

function recordframes!(matrix, nframes)
    if !matrix.debug
        for _ = 1:nframes
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
function show_death!(matrix, pivot; nframes = 1)
    if !matrix.debug
        clear_column!(matrix.plot)
        show_death!(matrix.plot, pivot)
        if !is_cohomology(matrix)
            show_chain!(matrix, pivot)
        end
    end
end

function Ripserer.reduce_column!(matrix::VisualMatrix, column_to_reduce)
    clear_buffer!(matrix.reduced)
    ###
    clear!(matrix)
    show_birth!(matrix, column_to_reduce)
    recordframes!(matrix, 1)
    if !is_cohomology(matrix)
        clear_birth!(matrix.plot)
    end
    ###

    pivot = initialize_coboundary!(matrix, column_to_reduce)

    while !isnothing(pivot)
        column = matrix.reduced[pivot]
        isempty(column) && break

        ###
        show_chain!(matrix, pivot)
        recordframes!(matrix, 1)
        ###
        add!(matrix, column, pivot)
        ###
        show_cocycle!(matrix, column_to_reduce)
        show_chain!(matrix, pivot)
        recordframes!(matrix, 1)
        ###
        pivot = pop!(matrix.chain)
    end
    if !isnothing(pivot)
        ###
        show_death!(matrix, pivot)
        recordframes!(matrix, 1)
        ###
        finalize!(matrix, column_to_reduce, pivot)
    end

    return pivot
end

function ripserer(
    data,
    filtration = Alpha(data);
    scene = Scene(),
    dim_max = 1,
    modulus = 2,
    field_type = Mod{modulus},
    alg = :cohomology,
    debug = false,
    framerate = 6,
    pre_chain_frames = 1,
    post_chain_frames = 1,
    col_frames = 1,
    birth_frames = 1,
    death_frames = 1,
)
    return ripserer(
        Val(alg),
        data,
        filtration,
        scene,
        dim_max,
        field_type,
        debug,
        framerate;
        pre_chain_frames,
        post_chain_frames,
        col_frames,
        birth_frames,
        death_frames,
    )
end

function ripserer(
    ::Val{:cohomology},
    data,
    filtration,
    scene,
    dim_max,
    field_type,
    debug,
    framerate;
    kwargs...,
)
    result = PersistenceDiagram[]
    zeroth, to_reduce, to_skip = zeroth_intervals(filtration, 0, true, field_type, false)
    push!(result, zeroth)
    stream = VideoStream(scene; framerate)
    if dim_max > 0
        matrix = CoboundaryMatrix{true}(field_type, filtration, to_reduce, to_skip)
        vmatrix = VisualMatrix(matrix, scene, stream, data, debug; kwargs...)
        for dim = 1:dim_max
            push!(result, compute_intervals!(vmatrix, 0, true, false))
            clear!(vmatrix)
            recordframes!(vmatrix, 5)
            if dim < dim_max
                vmatrix = next_matrix(vmatrix, true)
            end
        end
    end
    return result, stream
end

function ripserer(
    ::Val{:homology},
    data,
    filtration,
    scene,
    dim_max,
    field_type,
    debug,
    framerate;
    kwargs...,
)
    result = PersistenceDiagram[]
    zeroth, to_reduce, to_skip = zeroth_intervals(filtration, 0, true, field_type, false)
    push!(result, zeroth)
    stream = VideoStream(scene; framerate)

    if dim_max > 0
        simplices = columns_to_reduce(filtration, Iterators.flatten((to_reduce, to_skip)))
        for dim = 1:dim_max
            matrix = BoundaryMatrix{false}(field_type, filtration, simplices)
            vmatrix = VisualMatrix(matrix, scene, stream, data, debug; kwargs...)
            push!(result, compute_intervals!(vmatrix, 0, true, false))
            clear!(vmatrix)
            recordframes!(vmatrix, 5)
            if dim < dim_max
                simplices = columns_to_reduce(filtration, simplices)
            end
        end
    end

    return result, stream
end

function ripserer(
    ::Val{:involuted},
    data,
    filtration,
    scene,
    dim_max,
    field_type,
    debug,
    framerate;
    kwargs...,
)
    result = PersistenceDiagram[]
    zeroth, to_reduce, to_skip = zeroth_intervals(filtration, 0, true, field_type, false)
    push!(result, zeroth)
    stream = VideoStream(scene; framerate)

    if dim_max > 0
        comatrix = CoboundaryMatrix{true}(field_type, filtration, to_reduce, to_skip)
        for dim = 1:dim_max
            columns, inf_births = compute_death_simplices!(comatrix, progress, cutoff)
            matrix = BoundaryMatrix{implicit}(field_type, filtration, columns)
            vmatrix = VisualMatrix(matrix, scene, stream, data, debug; kwargs...)
            diagram = compute_intervals!(matrix, 0, true, false)
            for birth_simplex in inf_births
                push!(
                    diagram.intervals,
                    interval(comatrix, birth_simplex, nothing, 0, _reps(reps, dim)),
                )
            end
            push!(result, diagram)
            clear!(vmatrix)
            recordframes!(vmatrix, 5)
            if dim < dim_max
                comatrix = next_matrix(comatrix, progress)
            end
        end
    end
    return result
end
