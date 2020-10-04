module MakieRipserer

using AbstractPlotting
using ColorSchemes
using IterTools
using PersistenceDiagrams
using Ripserer

using AbstractPlotting:
    Plot, PointBased, Triangle
using Ripserer:
    AbstractSimplex, AbstractFiltration, AbstractRipsFiltration, AbstractChainElement

export plot_barcode, plot_diagram

const DEFAULT_PALETTE = :tab10

# This allows us to provide either color names or integers for colors.
function get_color(p, name)
    lift(p[name], p[:palette]) do color, scheme
        if color isa Integer
            colorschemes[scheme][color]
        else
            color
        end
    end
end

# These options can be passed to a chain or simplex.
const CHAIN_ARGS = (
    pointcolor = 1,
    edgecolor = :black,
    trianglecolor = 2,
    shading = false,
    transparency = false,
    palette = DEFAULT_PALETTE,
    markersize = 1,
    linewidth = 1,
)

function forward_chain_args(p)
    [name => p[name] for name in keys(CHAIN_ARGS)]
end

include("chain.jl")
include("filtration.jl")
include("diagrams.jl")
include("app.jl")

end
