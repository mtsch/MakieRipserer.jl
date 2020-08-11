module MakieRipserer

using AbstractPlotting
using AbstractPlotting: Plot

using ColorSchemes

using Ripserer
using Ripserer:
    AbstractSimplex, AbstractFiltration, AbstractRipsFiltration, AbstractChainElement

using PersistenceDiagrams

export plot_diagram, plot_barcode

const DEFAULT_PALETTE = :tab10

# If color is an Integer, get it from palette, otherwise return it.
function get_color(p, name)
    lift(p[name], p[:palette]) do color, scheme
        if color isa Integer
            colorschemes[scheme][color]
        else
            color
        end
    end
end

include("rips.jl")
include("chain.jl")
include("diagrams.jl")
include("app.jl")

end # module
