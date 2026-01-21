# Policy implementations for SimOptDecisions

"""
    StaticPolicy{T<:Real} <: SimOptDecisions.AbstractPolicy

Policy that returns fixed lever settings in year 1, zero otherwise.
"""
struct StaticPolicy{T<:Real} <: SimOptDecisions.AbstractPolicy
    levers::Levers{T}
end

function StaticPolicy(params::AbstractVector{T}) where {T<:Real}
    @assert length(params) == 5 "StaticPolicy requires 5 parameters [W, R, P, D, B]"
    StaticPolicy(Levers{T}(params[1], params[2], params[3], params[4], params[5]))
end

function StaticPolicy{T}(params::AbstractVector) where {T<:Real}
    @assert length(params) == 5 "StaticPolicy requires 5 parameters [W, R, P, D, B]"
    StaticPolicy(Levers{T}(T(params[1]), T(params[2]), T(params[3]), T(params[4]), T(params[5])))
end

# Callable: returns levers in year 1, zero otherwise
function (policy::StaticPolicy{T})(state, forcing, year) where {T}
    year == 1 ? policy.levers : Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T))
end

# SimOptDecisions interface
function SimOptDecisions.params(policy::StaticPolicy{T}) where {T}
    T[policy.levers.W, policy.levers.R, policy.levers.P, policy.levers.D, policy.levers.B]
end

function SimOptDecisions.param_bounds(::Type{<:StaticPolicy})
    [(0.0, 50.0), (0.0, 50.0), (0.0, 0.99), (0.0, 50.0), (0.0, 50.0)]
end

# Callback 3: get_action
function SimOptDecisions.get_action(
    policy::SimOptDecisions.AbstractPolicy,
    state::State,
    t::SimOptDecisions.TimeStep,
    scenario::EADScenario
)
    policy(state, scenario.forcing, t.val)
end

function SimOptDecisions.get_action(
    policy::SimOptDecisions.AbstractPolicy,
    state::State,
    t::SimOptDecisions.TimeStep,
    scenario::StochasticScenario
)
    policy(state, scenario.forcing, t.val)
end

Base.show(io::IO, p::StaticPolicy) = print(io, "StaticPolicy(", p.levers, ")")
