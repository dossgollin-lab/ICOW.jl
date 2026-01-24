# Configuration type for ICOW simulations
# Config holds fixed parameters that don't change across scenarios

# Include Core submodule
include("Core/Core.jl")
using .Core

"""
    ICOWConfig{T} <: SimOptDecisions.AbstractConfig

Configuration wrapping Core.CityParameters.
"""
struct ICOWConfig{T<:Real} <: SimOptDecisions.AbstractConfig
    city::Core.CityParameters{T}
end

# Convenience constructor
ICOWConfig() = ICOWConfig(Core.CityParameters())

# Forward CityParameters fields
Base.getproperty(c::ICOWConfig, s::Symbol) = s === :city ? getfield(c, :city) : getproperty(getfield(c, :city), s)

# Display
function Base.show(io::IO, c::ICOWConfig)
    print(io, "ICOWConfig(", c.city, ")")
end
