# Policy interface and implementations
# AbstractPolicy is defined in types.jl

raw"""
# Policy Interface

Policies in iCOW follow the Powell framework for sequential decision-making under uncertainty.

A policy $\pi = (f, \theta)$ consists of:
- $f \in \mathcal{F}$: The policy **type** (e.g., `StaticPolicy`, future: `ThresholdPolicy`)
- $\theta \in \Theta^f$: Tunable **parameters** for that type

## Implementation Pattern: Callable Structs

Policies are implemented as **callable structs** that follow this interface:

```julia
struct MyPolicy{T<:Real} <: AbstractPolicy{T}
    # Policy parameters go here
end

# Make policy callable: (state, forcing, year) -> Levers
function (policy::MyPolicy)(state, forcing, year)
    # Decision logic here
    return Levers(...)
end
```

The callable interface receives:
- `state`: Current protection state (`StochasticState` or `EADState`)
- `forcing`: Forcing data (`StochasticForcing` or `DistributionalForcing`)
- `year`: Current simulation year (0-indexed from start year)

And returns:
- `Levers{T}`: **Target** lever settings (W, R, P, D, B)

Note: The simulation engine enforces irreversibility. Policies return target levers;
the engine ensures `next_levers = max.(current_levers, target_levers)`.

## Parameter Extraction for Optimization

Policies must implement:

```julia
parameters(policy::MyPolicy) -> AbstractVector{T}
```

This extracts the tunable parameters $\theta$ as a vector for optimization algorithms.

## Round-Trip Capability

For optimization, policies must support reconstruction from parameters:

```julia
policy_reconstructed = MyPolicy(parameters(policy))
```

This enables the optimization loop: optimize $\theta$ → reconstruct policy → evaluate.

## References

See `docs/roadmap/README.md` for details on the Powell framework and sequential decision structure.
"""

"""
    StaticPolicy{T<:Real} <: AbstractPolicy{T}

Policy that returns fixed lever settings regardless of state or time.

# Constructors

    StaticPolicy(levers::Levers{T})
    StaticPolicy(params::AbstractVector{T}) where {T<:Real}

Construct from either `Levers` or a parameter vector `[W, R, P, D, B]`.
"""
struct StaticPolicy{T<:Real} <: AbstractPolicy{T}
    levers::Levers{T}
end

# Reverse constructor: reconstruct policy from parameter vector
function StaticPolicy(params::AbstractVector{T}) where {T<:Real}
    @assert length(params) == 5 "StaticPolicy requires 5 parameters [W, R, P, D, B]"
    return StaticPolicy(Levers{T}(params[1], params[2], params[3], params[4], params[5]))
end

# Callable interface: returns fixed levers in year 1, zero levers otherwise
function (policy::StaticPolicy{T})(state, forcing, year) where {T}
    if year == 1
        return policy.levers
    else
        return Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T))
    end
end

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

"""
    valid_bounds(::Type{StaticPolicy}, city)

Return (lower, upper) bounds for StaticPolicy parameters [W, R, P, D, B].
"""
function valid_bounds(::Type{StaticPolicy}, city::CityParameters{T}) where {T<:Real}
    lower = (zero(T), zero(T), zero(T), zero(T), zero(T))
    upper = (city.H_city, city.H_city, T(0.99), city.H_city, city.H_city)
    return (lower, upper)
end
