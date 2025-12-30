# State types for stochastic and EAD simulation modes

"""
    StochasticState{T<:Real} <: AbstractSimulationState{T}

Mutable state for stochastic simulation mode.
"""
mutable struct StochasticState{T<:Real} <: AbstractSimulationState{T}
    current_levers::Levers{T}
    accumulated_cost::T
    accumulated_damage::T
    current_year::Int
end

# Outer constructor: initialize accumulators to zero at year 1
StochasticState(levers::Levers{T}) where {T} = StochasticState(levers, zero(T), zero(T), 1)

"""
    EADState{T<:Real} <: AbstractSimulationState{T}

Mutable state for Expected Annual Damage (EAD) simulation mode.
"""
mutable struct EADState{T<:Real} <: AbstractSimulationState{T}
    current_levers::Levers{T}
    accumulated_cost::T
    accumulated_ead::T
    current_year::Int
end

# Outer constructor: initialize accumulators to zero at year 1
EADState(levers::Levers{T}) where {T} = EADState(levers, zero(T), zero(T), 1)
