# Policy types for ICOW simulations
# Policies map (state, scenario, time) -> action

"""
    StaticPolicy{T} <: SimOptDecisions.AbstractPolicy

Policy that applies fixed lever settings in year 1.
"""
struct StaticPolicy{T<:Real} <: SimOptDecisions.AbstractPolicy
    levers::Core.Levers{T}
end

# Constructor from parameter vector (for optimization)
function StaticPolicy(params::AbstractVector{T}) where {T<:Real}
    @assert length(params) == 5 "StaticPolicy requires 5 parameters [W, R, P, D, B]"
    StaticPolicy(Core.Levers{T}(params[1], params[2], params[3], params[4], params[5]))
end

# Parameterized constructor for optimization
function StaticPolicy{T}(params::AbstractVector) where {T<:Real}
    @assert length(params) == 5 "StaticPolicy requires 5 parameters [W, R, P, D, B]"
    StaticPolicy(Core.Levers{T}(T(params[1]), T(params[2]), T(params[3]), T(params[4]), T(params[5])))
end

# SimOptDecisions interface: extract parameters as vector
function SimOptDecisions.params(policy::StaticPolicy{T}) where {T}
    return T[policy.levers.W, policy.levers.R, policy.levers.P, policy.levers.D, policy.levers.B]
end

# SimOptDecisions interface: parameter bounds for optimization
function SimOptDecisions.param_bounds(::Type{<:StaticPolicy})
    # Generic bounds - actual feasibility enforced in run_timestep
    return [(0.0, 50.0), (0.0, 50.0), (0.0, 0.99), (0.0, 50.0), (0.0, 50.0)]
end

# Display
function Base.show(io::IO, p::StaticPolicy)
    print(io, "StaticPolicy(", p.levers, ")")
end
