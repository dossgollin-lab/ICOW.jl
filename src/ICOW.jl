module ICOW

using Random
using Statistics
using Distributions
using QuadGK
using SimOptDecisions
using Metaheuristics

# Core types
include("parameters.jl")
include("types.jl")
include("forcing.jl")
include("states.jl")
include("policies.jl")

# Physics
include("geometry.jl")
include("costs.jl")
include("zones.jl")
include("damage.jl")

# SimOptDecisions callbacks
include("simulation.jl")

# Optimization
include("optimization.jl")

# Visualization
include("visualization.jl")

# Core types
export CityParameters, validate_parameters, city_slope
export Levers, is_feasible
export State
export StaticPolicy

# Forcing and Scenarios
export StochasticForcing, DistributionalForcing
export EADScenario, StochasticScenario
export n_scenarios, n_years, get_surge, get_distribution, get_sea_level

# Physics
export calculate_dike_volume
export calculate_withdrawal_cost, calculate_value_after_withdrawal
export calculate_resistance_cost_fraction, calculate_resistance_cost
export calculate_dike_cost, calculate_investment_cost
export calculate_effective_surge, calculate_dike_failure_probability

# Zones and damage
export Zone, CityZones, ZoneType, calculate_city_zones
export ZONE_WITHDRAWN, ZONE_RESISTANT, ZONE_UNPROTECTED, ZONE_DIKE_PROTECTED, ZONE_ABOVE_DIKE
export calculate_zone_damage, calculate_event_damage, calculate_event_damage_stochastic
export calculate_expected_damage_given_surge
export calculate_expected_damage_mc, calculate_expected_damage_quad
export calculate_expected_damage

# Optimization
export optimize, pareto_policies, best_total

# Visualization
export plot_zones

end
