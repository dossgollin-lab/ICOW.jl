module ICOW

using Random
using Distributions
using QuadGK
using SimOptDecisions

# Types (plain structs, no dependencies)
include("types.jl")
export FloodDefenses, CityParameters
export validate_parameters, is_feasible

# Core submodule (pure physics functions)
include("Core/Core.jl")
using .Core

# =============================================================================
# SimOptDecisions Integration: Types
# =============================================================================

# Config wraps CityParameters
struct Config{T<:Real} <: AbstractConfig
    city::CityParameters{T}
end
Config() = Config(CityParameters{Float64}())
Base.getproperty(c::Config, s::Symbol) = s === :city ? getfield(c, :city) : getproperty(getfield(c, :city), s)
export Config

# Scenario: pre-sampled surges
struct Scenario{T<:Real} <: AbstractScenario
    surges::Vector{T}
    discount_rate::T
end
Scenario(surges::Vector{T}; discount_rate::T=zero(T)) where {T<:Real} = Scenario{T}(surges, discount_rate)
export Scenario

# State: current protection levels
mutable struct State{T<:Real} <: AbstractState
    defenses::FloodDefenses{T}
end
State() = State(FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0))
export State

# StaticPolicy: apply fixed protection in year 1
struct StaticPolicy{T<:Real} <: AbstractPolicy
    W::T
    R::T
    P::T
    D::T
    B::T
end

# Construct FloodDefenses when needed
defenses(p::StaticPolicy{T}) where {T} = FloodDefenses{T}(p.W, p.R, p.P, p.D, p.B)

# SimOptDecisions interface: flatten to vector for optimization/YAXArrays
SimOptDecisions.params(p::StaticPolicy) = [p.W, p.R, p.P, p.D, p.B]

export StaticPolicy, defenses

# StepRecord: per-timestep data for aggregation
struct StepRecord{T<:Real}
    investment::T
    damage::T
end
export StepRecord

# Outcome: final simulation result
struct Outcome{T<:Real} <: AbstractOutcome
    investment::T
    damage::T
end
total_cost(o::Outcome) = o.investment + o.damage
export Outcome, total_cost

# =============================================================================
# SimOptDecisions Integration: Simulation
# =============================================================================

include("simulation.jl")

# Re-export simulate from SimOptDecisions (works via dispatch on our types)
export simulate

end # module ICOW
