module ICOW

# Phase 1: Parameters & Validation
include("parameters.jl")
include("types.jl")

# Phase 2: Type System & Simulation Modes
include("forcing.jl")
include("states.jl")
include("policies.jl")

# Export Phase 1: Parameters & Validation
export CityParameters, validate_parameters, city_slope
export Levers, is_feasible

# Export Phase 2: Abstract types
export AbstractForcing, AbstractSimulationState, AbstractPolicy

# Export Phase 2: Forcing types
export StochasticForcing, DistributionalForcing
export n_scenarios, n_years, get_surge, get_distribution

# Export Phase 2: State types
export StochasticState, EADState

# Export Phase 2: Policy types
export StaticPolicy, parameters

end # module ICOW
