# Policy interface and implementations
# AbstractPolicy is defined in types.jl

"""
    StaticPolicy{T<:Real} <: AbstractPolicy{T}

Policy that returns fixed lever settings regardless of state or time.
"""
struct StaticPolicy{T<:Real} <: AbstractPolicy{T}
    levers::Levers{T}
end

# Callable interface: returns fixed levers (ignores state, forcing, year)
(policy::StaticPolicy)(state, forcing, year) = policy.levers

"""Extract policy parameters as a vector for optimization."""
function parameters end

# StaticPolicy parameters: the 5 lever values
parameters(policy::StaticPolicy{T}) where {T} = T[
    policy.levers.W,
    policy.levers.R,
    policy.levers.P,
    policy.levers.D,
    policy.levers.B
]
