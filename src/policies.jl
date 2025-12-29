# Policy interface and implementations

"""
    AbstractPolicy{T<:Real}

Abstract base type for decision policies.

Policies are callable structs that determine lever settings based on
the current state, forcing, and simulation year.

# Interface

All policies must implement:

- `(policy::AbstractPolicy)(state, forcing, year) -> Levers`: Returns lever settings
- `parameters(policy) -> AbstractVector`: Returns policy parameters for optimization

# Examples

```julia
# StaticPolicy always returns the same levers
policy = StaticPolicy(Levers(1.0, 2.0, 0.5, 3.0, 1.0))
levers = policy(state, forcing, 1)  # Returns the fixed levers
```
"""
# AbstractPolicy is defined in types.jl

"""
    StaticPolicy{T<:Real} <: AbstractPolicy{T}

A policy that returns fixed lever settings regardless of state or time.

This represents a "static" or "commit now" strategy where all decisions
are made at t=0 and do not adapt to observed conditions.

# Fields

- `levers::Levers{T}`: The fixed lever settings to apply

# Examples

```julia
levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
policy = StaticPolicy(levers)

# Calling the policy returns the same levers regardless of inputs
result = policy(state, forcing, year)  # == levers
```
"""
struct StaticPolicy{T<:Real} <: AbstractPolicy{T}
    levers::Levers{T}
end

# Callable interface: returns fixed levers (ignores state, forcing, year)
(policy::StaticPolicy)(state, forcing, year) = policy.levers

"""
    parameters(policy::AbstractPolicy) -> AbstractVector

Extract the policy parameters as a vector for optimization.

Returns the tunable parameters that define the policy behavior.
Used by optimization algorithms to search over policy space.
"""
function parameters end

# StaticPolicy parameters: the 5 lever values
parameters(policy::StaticPolicy{T}) where {T} = T[
    policy.levers.W,
    policy.levers.R,
    policy.levers.P,
    policy.levers.D,
    policy.levers.B
]
