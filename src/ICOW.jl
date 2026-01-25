module ICOW

# Types (plain structs, no dependencies)
include("types.jl")
export FloodDefenses

# Core submodule (pure physics functions)
include("Core/Core.jl")
using .Core

# Stochastic submodule (SimOptDecisions integration)
include("Stochastic/Stochastic.jl")
using .Stochastic
export Stochastic

end # module ICOW
