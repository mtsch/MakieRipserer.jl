module MakieRipserer

using AbstractPlotting
using IterTools
using PersistenceDiagrams
using PlotUtils
using ProgressMeter
using Ripserer

using AbstractPlotting:
    Plot, PointBased, Triangle
using Ripserer:
    AbstractSimplex, AbstractFiltration, AbstractRipsFiltration, AbstractChainElement
using GeometryBasics:
    GLTriangleFace

import GeometryBasics

export plot_barcode, FilteredChain, ObservableChain

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

include("conversion.jl")
include("filteredchain.jl")
include("observablechain.jl")
include("diagrams.jl")
include("observablediagrams.jl")
include("app.jl")
include("ripserer.jl")

end
