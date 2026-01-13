# Simulation state
# State = information needed for decision-making, updated by actions and exogenous information

"""
    State{T<:Real} <: SimOptDecisions.AbstractState

Current state of the system: protection levels and time.
Used by policies to make decisions.
"""
mutable struct State{T<:Real} <: SimOptDecisions.AbstractState
    current_levers::Levers{T}
    current_year::Int
end

State(levers::Levers{T}) where {T} = State(levers, 1)
