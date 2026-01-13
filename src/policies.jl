# Policy interface and implementations
# Policies inherit from SimOptDecisions.AbstractPolicy

raw"""
# Policy Interface

Policies in iCOW follow the Powell framework for sequential decision-making under uncertainty.
See docs/framework.md for details.

Policies inherit from `SimOptDecisions.AbstractPolicy` and must implement:
- `SimOptDecisions.params(policy)` - Extract parameters as vector
- `SimOptDecisions.param_bounds(::Type{PolicyType})` - Return parameter bounds
- Vector constructor `PolicyType(params::AbstractVector)` - Reconstruct from parameters
"""

"""
    StaticPolicy{T<:Real} <: SimOptDecisions.AbstractPolicy

Policy that returns fixed lever settings regardless of state or time.

# Constructors

    StaticPolicy(levers::Levers{T})
    StaticPolicy(params::AbstractVector{T}) where {T<:Real}

Construct from either `Levers` or a parameter vector `[W, R, P, D, B]`.
"""
struct StaticPolicy{T<:Real} <: SimOptDecisions.AbstractPolicy
    levers::Levers{T}
end

# Reverse constructor: reconstruct policy from parameter vector
function StaticPolicy(params::AbstractVector{T}) where {T<:Real}
    @assert length(params) == 5 "StaticPolicy requires 5 parameters [W, R, P, D, B]"
    return StaticPolicy(Levers{T}(params[1], params[2], params[3], params[4], params[5]))
end

# Parameterized constructor for optimization (SimOptDecisions requires this signature)
function StaticPolicy{T}(params::AbstractVector) where {T<:Real}
    @assert length(params) == 5 "StaticPolicy requires 5 parameters [W, R, P, D, B]"
    return StaticPolicy(Levers{T}(T(params[1]), T(params[2]), T(params[3]), T(params[4]), T(params[5])))
end

# Callable interface: returns fixed levers in year 1, zero levers otherwise
function (policy::StaticPolicy{T})(state, forcing, year) where {T}
    if year == 1
        return policy.levers
    else
        return Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T))
    end
end

# =============================================================================
# SimOptDecisions interface
# =============================================================================

"""Extract policy parameters as a vector for SimOptDecisions."""
function SimOptDecisions.params(policy::StaticPolicy{T}) where {T}
    return T[policy.levers.W, policy.levers.R, policy.levers.P, policy.levers.D, policy.levers.B]
end

"""Return parameter bounds for SimOptDecisions optimization."""
function SimOptDecisions.param_bounds(::Type{<:StaticPolicy})
    # Generic bounds - actual feasibility enforced via FeasibilityConstraint
    return [(0.0, 50.0), (0.0, 50.0), (0.0, 0.99), (0.0, 50.0), (0.0, 50.0)]
end

"""
    SimOptDecisions.get_action(policy, state, sow::EADSOW, t::TimeStep)

Fallback: delegates to callable interface `policy(state, forcing, year)`.
"""
function SimOptDecisions.get_action(
    policy::SimOptDecisions.AbstractPolicy, state::State, sow::EADSOW, t::SimOptDecisions.TimeStep
)
    return policy(state, sow.forcing, t.val)
end

"""
    SimOptDecisions.get_action(policy, state, sow::StochasticSOW, t::TimeStep)

Fallback: delegates to callable interface `policy(state, forcing, year)`.
"""
function SimOptDecisions.get_action(
    policy::SimOptDecisions.AbstractPolicy, state::State, sow::StochasticSOW, t::SimOptDecisions.TimeStep
)
    return policy(state, sow.forcing, t.val)
end

# =============================================================================
# Backward compatibility
# =============================================================================

"""Extract policy parameters as a vector for optimization (deprecated, use SimOptDecisions.params)."""
parameters(policy::StaticPolicy) = SimOptDecisions.params(policy)

"""
    valid_bounds(::Type{StaticPolicy}, city)

Return (lower, upper) bounds for StaticPolicy parameters [W, R, P, D, B].
City-specific bounds (tighter than param_bounds).
"""
function valid_bounds(::Type{StaticPolicy}, city::CityParameters{T}) where {T<:Real}
    lower = (zero(T), zero(T), zero(T), zero(T), zero(T))
    upper = (city.H_city, city.H_city, T(0.99), city.H_city, city.H_city)
    return (lower, upper)
end

# Display method - delegates to Levers
function Base.show(io::IO, p::StaticPolicy)
    print(io, "StaticPolicy(", p.levers, ")")
end
