module ICOW

using Random
using Statistics
using Distributions
using QuadGK

# Phase 1: Parameters & Validation
include("parameters.jl")
include("types.jl")

# Phase 2: Type System & Simulation Modes
include("forcing.jl")
include("states.jl")
include("policies.jl")

# Phase 3: Geometry
include("geometry.jl")

# Phase 4: Costs and Dike Failure
include("costs.jl")

# Phase 5: Zones & Event Damage
include("zones.jl")
include("damage.jl")

# Phase 7: Simulation Engine & Objectives
include("simulation.jl")
include("objectives.jl")

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

# Export Phase 3: Geometry
export calculate_dike_volume

# Export Phase 4: Costs and Dike Failure
export calculate_withdrawal_cost, calculate_value_after_withdrawal
export calculate_resistance_cost_fraction, calculate_resistance_cost
export calculate_dike_cost, calculate_investment_cost
export calculate_effective_surge, calculate_dike_failure_probability

# Export Phase 5: Zones & Event Damage
export AbstractZone
export WithdrawnZone, ResistantZone, UnprotectedZone, DikeProtectedZone, AboveDikeZone
export CityZones, calculate_city_zones
export calculate_zone_damage, calculate_event_damage, calculate_event_damage_stochastic

# Export Phase 6: Expected Annual Damage Integration
export calculate_expected_damage_given_surge
export calculate_expected_damage_mc, calculate_expected_damage_quad
export calculate_expected_damage

# Export Phase 7: Simulation Engine & Objectives
export simulate
export apply_discount, calculate_npv, objective_total_cost

end # module ICOW
