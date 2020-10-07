using Test

using AbstractPlotting
using MakieRipserer
using Ripserer

data = [(sin(t), cos(t)) for t in range(0, 2π, length=13)[1:12]]

# Just make sure nothing throws.
time = Observable(0.0)
@test begin
    MakieRipserer.app(data, Rips(data); time)
    time[] = 1
    true
end
