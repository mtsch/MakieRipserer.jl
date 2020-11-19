using MakieRipserer
using Aqua

# Don't test for ambiguities. There are too many in imported packages.
Aqua.test_all(MakieRipserer; ambiguities=false)
