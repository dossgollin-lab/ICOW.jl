module ICOW

# Phase 0: Parameters & Validation
include("parameters.jl")
include("types.jl")

# Export main types and functions
export CityParameters, validate_parameters
export Levers, is_feasible

end # module ICOW
