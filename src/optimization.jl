# Optimization interface using BlackBoxOptim.jl
# Thin wrapper for multi-objective simulation-optimization

using BlackBoxOptim

"""
    optimize(city, forcings, discount_rate; kwargs...)

Multi-objective optimization using BlackBoxOptim. See docs/roadmap/phase09_optimization.md.
"""
function optimize(
    city::CityParameters{T},
    forcings::Vector{<:AbstractForcing},
    discount_rate::Real;
    policy_type::Type{<:AbstractPolicy}=StaticPolicy,
    aggregator::Function=mean,
    max_steps::Int=10000,
    population_size::Int=100,
    kwargs...
) where {T<:Real}
    # Get bounds from policy
    (lower, upper) = valid_bounds(policy_type, city)
    search_range = [(lower[i], upper[i]) for i in eachindex(lower)]

    # Objective function: params -> (investment, damage)
    function objective(params)
        # Reconstruct policy from parameter vector
        policy = try
            policy_type(T.(params))
        catch
            return (T(Inf), T(Inf))
        end

        # Check feasibility before simulation
        if !is_feasible(policy.levers, city)
            return (T(Inf), T(Inf))
        end

        # Simulate across all SOWs
        investments = T[]
        damages = T[]
        for forcing in forcings
            (inv, dmg) = simulate(city, policy, forcing;
                                   mode=:scalar, discount_rate=discount_rate)
            if isinf(inv)
                return (T(Inf), T(Inf))
            end
            push!(investments, inv)
            push!(damages, dmg)
        end

        # Aggregate across SOWs
        return (aggregator(investments), aggregator(damages))
    end

    # Run optimization
    result = bboptimize(
        objective;
        Method=:borg_moea,
        FitnessScheme=ParetoFitnessScheme{2}(is_minimizing=true),
        SearchRange=search_range,
        NumDimensions=length(lower),
        MaxSteps=max_steps,
        PopulationSize=population_size,
        TraceMode=:silent,
        kwargs...
    )

    return result
end

"""
    pareto_policies(result, policy_type)

Extract policies from the Pareto frontier of an optimization result.
"""
function pareto_policies(result, policy_type::Type{<:AbstractPolicy}=StaticPolicy)
    frontier = pareto_frontier(result)
    return [policy_type(BlackBoxOptim.params(ind.inner)) for ind in frontier]
end

"""
    best_total(result, policy_type)

Extract the policy with minimum total cost (investment + damage) from an optimization result.
"""
function best_total(result, policy_type::Type{<:AbstractPolicy}=StaticPolicy)
    return policy_type(best_candidate(result))
end
