function ReductionPlot(chain, column, birth_simplex, death_simplex, data, scene)
    _data = convert_arguments(Scatter, data)[1]
    rp = ReductionPlot(
        ObservableChain(chain, data),
        ObservableChain(column, data),
        ObservableChain(birth_simplex, data),
        ObservableChain(death_simplex, data),
        _data,
        scene,
    )
    plot!(scene, rp.data)
    plot!(scene, rp.chain; color=2)
    plot!(scene, rp.column; color=3)
    plot!(scene, rp.death_simplex; color=4)
    plot!(scene, rp.birth_simplex; color=1)
    return rp
end

show_chain!(rp::ReductionPlot, chain) = set!(rp.chain, chain)
show_column!(rp::ReductionPlot, column) = set!(rp.column, column)
show_birth!(rp::ReductionPlot, sx::Simplex) = set!(rp.birth_simplex, [sx])
show_birth!(rp::ReductionPlot, vec::AbstractVector) = set!(rp.birth_simplex, vec)
show_death!(rp::ReductionPlot, sx) = set!(rp.death_simplex, [sx])
clear_chain!(rp::ReductionPlot) = clear!(rp.chain)
clear_column!(rp::ReductionPlot) = clear!(rp.column)
clear_birth!(rp::ReductionPlot) = clear!(rp.birth_simplex)
clear_death!(rp::ReductionPlot) = clear!(rp.death_simplex)
function clear_all!(rp::ReductionPlot)
    clear_chain!(rp)
    clear_column!(rp)
    clear_birth!(rp)
    clear_death!(rp)
end

#=
using Ripserer: chain_element_type
using MakieRipserer: ObservableChain

bs = Simplex{1}(1,1)
ds = Simplex{2}(2,1)
ch = chain_element_type(Simplex{2,Int,Int}, Mod{2})
sxs = ch.([Simplex{2}(i, i) for i in 1:10])

oc1 = ObservableChain(sxs, t)
oc2 = ObservableChain(bs, t)
=#
