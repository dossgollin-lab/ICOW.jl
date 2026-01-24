module ICOW

using Random
using Distributions
using QuadGK
using SimOptDecisions
using Metaheuristics  # Activates SimOptDecisions optimization backend

# Core submodule (pure physics functions)
include("config.jl")  # Also includes Core/Core.jl

# SimOptDecisions types
include("forcing.jl")
include("scenarios.jl")
include("states.jl")
include("policies.jl")
include("outcomes.jl")

# Five-callback simulation implementation
include("simulation.jl")

# Optimization
include("optimization.jl")

# ============================================================================
# Exports
# ============================================================================

# Core types (re-exported)
const Levers = Core.Levers
const CityParameters = Core.CityParameters
const validate_parameters = Core.validate_parameters
const is_feasible = Core.is_feasible
export Levers, CityParameters, validate_parameters, is_feasible

# Config, Scenarios, State, Policy, Outcome
export ICOWConfig
export EADScenario, StochasticScenario
export ICOWState, StaticPolicy
export ICOWOutcome, total_cost

# Forcing
export StochasticForcing, DistributionalForcing
export n_scenarios, n_years, get_surge, get_distribution

# Optimization
export optimize, pareto_policies, best_total, valid_bounds

end # module ICOW
