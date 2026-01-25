# Core physics submodule for the iCOW model
# Pure numeric functions validated against C++ reference implementation
# No structs - types live in main ICOW module

module Core

# Pure numeric functions
include("geometry.jl")
include("costs.jl")
include("zones.jl")
include("damage.jl")

# Export geometry
export dike_volume

# Export costs
export withdrawal_cost, value_after_withdrawal
export resistance_cost_fraction, resistance_cost
export dike_cost
export effective_surge, dike_failure_probability

# Export zones
export zone_boundaries, zone_values

# Export damage
export base_zone_damage, zone_damage
export total_event_damage, expected_damage_given_surge

end # module Core
