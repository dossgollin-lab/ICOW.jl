# State type for ICOW simulations

"""
    ICOWState{T} <: SimOptDecisions.AbstractState

Current protection levels (enforces irreversibility across timesteps).
"""
mutable struct ICOWState{T<:Real} <: SimOptDecisions.AbstractState
    current_levers::Core.Levers{T}
end

ICOWState{T}() where {T<:Real} = ICOWState(Core.Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)))
ICOWState() = ICOWState{Float64}()
