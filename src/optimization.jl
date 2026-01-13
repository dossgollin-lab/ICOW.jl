# Optimization interface - stub until Phase E implementation
# TODO: Implement using SimOptDecisions.MetaheuristicsBackend

"""
    optimize(city, forcings, discount_rate; kwargs...)

Multi-objective optimization. Not yet implemented - pending Phase E.
"""
function optimize(args...; kwargs...)
    error("optimize() not yet implemented. See ROADMAP.md Phase E.")
end

"""
    pareto_policies(result, policy_type)

Extract policies from optimization result. Not yet implemented.
"""
function pareto_policies(args...; kwargs...)
    error("pareto_policies() not yet implemented. See ROADMAP.md Phase E.")
end

"""
    best_total(result, policy_type)

Extract best policy from optimization result. Not yet implemented.
"""
function best_total(args...; kwargs...)
    error("best_total() not yet implemented. See ROADMAP.md Phase E.")
end
