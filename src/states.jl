# State type for ICOW simulations
# State = information needed for decision-making, updated by actions

"""
    ICOWState{T} <: SimOptDecisions.AbstractState

Current state of the system: protection levels and time.
"""
mutable struct ICOWState{T<:Real} <: SimOptDecisions.AbstractState
    current_levers::Core.Levers{T}
    current_year::Int
end

ICOWState(levers::Core.Levers{T}) where {T} = ICOWState{T}(levers, 1)

# Convenience constructor with zero levers
function ICOWState{T}() where {T<:Real}
    ICOWState(Core.Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)))
end

ICOWState() = ICOWState{Float64}()
