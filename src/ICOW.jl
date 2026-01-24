module ICOW

using Random
using Statistics
using Distributions
using QuadGK
using SimOptDecisions
using Metaheuristics  # Activates SimOptDecisions optimization backend

# Core submodule (pure physics functions)
include("config.jl")  # Also includes Core/Core.jl

# Forcing data types
include("forcing.jl")

# New SimOptDecisions types
include("scenarios.jl")
include("states.jl")
include("policies.jl")
include("outcomes.jl")

# Five-callback simulation implementation
include("simulation.jl")

# Legacy files (kept for test compatibility, will be removed in Phase 5)
include("geometry.jl")
include("costs.jl")
include("zones.jl")
include("damage.jl")
include("objectives.jl")
include("optimization.jl")
include("visualization.jl")

# ============================================================================
# Exports: New API
# ============================================================================

# Core types (re-exported from Core)
const Levers = Core.Levers
const CityParameters = Core.CityParameters
const validate_parameters = Core.validate_parameters
const is_feasible = Core.is_feasible
export Levers, CityParameters
export validate_parameters, is_feasible

# Config and Scenarios
export ICOWConfig
export EADScenario, StochasticScenario

# State and Policy
export ICOWState, StaticPolicy

# Outcome
export ICOWOutcome, total_cost

# Forcing
export StochasticForcing, DistributionalForcing
export n_scenarios, n_years, get_surge, get_distribution

# Simulation (uses SimOptDecisions.simulate internally)
export simulate

# ============================================================================
# Exports: Legacy API (for test compatibility, will be removed in Phase 5)
# ============================================================================

# Old cost/damage functions
export calculate_dike_volume
export calculate_withdrawal_cost, calculate_value_after_withdrawal
export calculate_resistance_cost_fraction, calculate_resistance_cost
export calculate_dike_cost, calculate_investment_cost
export calculate_effective_surge, calculate_dike_failure_probability

# Old zone types
export Zone, CityZones, ZoneType, calculate_city_zones
export ZONE_WITHDRAWN, ZONE_RESISTANT, ZONE_UNPROTECTED, ZONE_DIKE_PROTECTED, ZONE_ABOVE_DIKE
export calculate_zone_damage, calculate_event_damage, calculate_event_damage_stochastic

# Old EAD functions
export calculate_expected_damage_given_surge
export calculate_expected_damage_mc, calculate_expected_damage_quad
export calculate_expected_damage

# Old objectives
export apply_discount, calculate_npv, objective_total_cost

# Old optimization
export valid_bounds
export optimize, pareto_policies, best_total

# Visualization
export plot_zones

end # module ICOW
