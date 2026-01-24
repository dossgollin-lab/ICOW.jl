# Core physics submodule for the iCOW model
# Pure functions validated against C++ reference implementation
# No SimOptDecisions dependencies

module Core

using Random

# Types (plain structs, no SimOptDecisions inheritance)
include("types.jl")

# Geometry (pure numeric + convenience wrappers)
include("geometry.jl")

# Costs (pure numeric + convenience wrappers)
include("costs.jl")

# Zones (pure numeric + convenience wrappers)
include("zones.jl")

# Damage (pure numeric + convenience wrappers)
include("damage.jl")

# Export types
export Levers, CityParameters
export validate_parameters, city_slope, is_feasible

# Export zone types
export Zone, CityZones, ZoneType
export ZONE_WITHDRAWN, ZONE_RESISTANT, ZONE_UNPROTECTED, ZONE_DIKE_PROTECTED, ZONE_ABOVE_DIKE

# Export geometry functions
export dike_volume

# Export cost functions
export withdrawal_cost, value_after_withdrawal
export resistance_cost_fraction, resistance_cost
export dike_cost, investment_cost
export effective_surge, dike_failure_probability

# Export zone functions
export zone_boundaries, zone_values, city_zones

# Export damage functions
export base_zone_damage, zone_damage, event_damage
export event_damage_stochastic, expected_damage_given_surge

end # module Core
