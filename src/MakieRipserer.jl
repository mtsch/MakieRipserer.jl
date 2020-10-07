module MakieRipserer

using AbstractPlotting
using IterTools
using PersistenceDiagrams
using PlotUtils
using Ripserer

using AbstractPlotting:
    Plot, PointBased, Triangle
using Ripserer:
    AbstractSimplex, AbstractFiltration, AbstractRipsFiltration, AbstractChainElement
using GeometryBasics:
    GLTriangleFace

import GeometryBasics

export plot_barcode

const DEFAULT_PALETTE = :default

# This allows us to provide either color names or integers for colors.
function get_color(p, name)
    lift(name, p[:palette]) do color, scheme
        if color isa Integer
            colors = PlotUtils.get_colorscheme(scheme)
            colors[mod1(color, length(colors))]
        else
            color
        end
    end
end

include("filtered_chain.jl")
#include("filtered.jl")
#include("chain.jl")
#include("filtration.jl")
include("diagrams.jl")
include("app.jl")

end
