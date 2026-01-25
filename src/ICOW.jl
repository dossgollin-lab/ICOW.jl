module ICOW

using Random
using Distributions
using QuadGK
using SimOptDecisions

# Types (plain structs, no dependencies)
include("types.jl")
export Levers, CityParameters
export validate_parameters, is_feasible

# Core submodule (pure physics functions)
include("Core/Core.jl")
using .Core

# Simple scenario: just pre-sampled surges
struct Scenario
    surges::Vector{Float64}  # surge per year
    discount_rate::Float64
end
Scenario(surges; discount_rate=0.0) = Scenario(surges, discount_rate)
export Scenario

# Config wraps CityParameters
struct Config
    city::CityParameters{Float64}
end
Config() = Config(CityParameters())
Base.getproperty(c::Config, s::Symbol) = s === :city ? getfield(c, :city) : getproperty(getfield(c, :city), s)
export Config

# State: current protection levels
mutable struct State
    levers::Levers{Float64}
end
State() = State(Levers(0.0, 0.0, 0.0, 0.0, 0.0))
export State

# Policy: what levers to apply
struct Policy
    levers::Levers{Float64}
end
Policy(W, R, P, D, B) = Policy(Levers(W, R, P, D, B))
export Policy

# Outcome: investment + damage
struct Outcome
    investment::Float64
    damage::Float64
end
total_cost(o::Outcome) = o.investment + o.damage
export Outcome, total_cost

# Simple simulate function
include("simulate.jl")
export simulate

end # module ICOW
