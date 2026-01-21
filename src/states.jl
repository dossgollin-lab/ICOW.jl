# Simulation state
# State = information needed for decision-making, updated by actions and exogenous information

"""
    State{T<:Real} <: SimOptDecisions.AbstractState

Current state of the system: protection levels and sea level.
Year is tracked via TimeStep in the simulation loop.
"""
mutable struct State{T<:Real} <: SimOptDecisions.AbstractState
    current_levers::Levers{T}
    current_sea_level::T
end

# Convenience constructors
State(levers::Levers{T}, sea_level::T) where {T} = State{T}(levers, sea_level)
State(levers::Levers{T}) where {T} = State{T}(levers, zero(T))  # Default: sea level = 0
