module ICOW

# Phase 1: Parameters & Validation
include("parameters.jl")
include("types.jl")

# Export main types and functions
export CityParameters, validate_parameters, city_slope
export Levers, is_feasible

end # module ICOW
