# Optimization interface using SimOptDecisions.MetaheuristicsBackend
# Multi-objective optimization over policy parameters

using Random

"""
    _create_scenarios(forcings::AbstractVector, discount_rate::Real)

Create Scenario objects from forcing data.
"""
function _create_scenarios(forcings::AbstractVector{<:StochasticForcing{T}}, discount_rate::Real) where {T}
    # For stochastic forcing, create one scenario per scenario index across all forcings
    scenarios = StochasticScenario{T}[]
    for forcing in forcings
        for idx in 1:n_scenarios(forcing)
            push!(scenarios, StochasticScenario(forcing, idx; discount_rate=T(discount_rate)))
        end
    end
    return scenarios
end

function _create_scenarios(forcings::AbstractVector{<:DistributionalForcing{T}}, discount_rate::Real) where {T}
    # For distributional forcing, create one scenario per forcing
    return [EADScenario(f; discount_rate=T(discount_rate), method=:quad) for f in forcings]
end

"""
    _metric_calculator(outcomes)

Aggregate simulation outcomes to optimization metrics.
Returns NamedTuple with (mean_investment, mean_damage).
"""
function _metric_calculator(outcomes)
    n = length(outcomes)
    mean_investment = sum(o.investment for o in outcomes) / n
    mean_damage = sum(o.damage for o in outcomes) / n
    return (mean_investment=mean_investment, mean_damage=mean_damage)
end

"""
    _feasibility_constraint(city::Core.CityParameters)

Create FeasibilityConstraint for lever validity.
"""
function _feasibility_constraint(city::Core.CityParameters)
    return SimOptDecisions.FeasibilityConstraint(:lever_feasibility, policy -> begin
        levers = policy.levers
        return Core.is_feasible(levers, city)
    end)
end

"""
    optimize(config, forcings, discount_rate; kwargs...)

Multi-objective optimization over StaticPolicy parameters.

# Arguments
- `config::ICOWConfig`: Configuration wrapping CityParameters
- `forcings`: Vector of forcing data (StochasticForcing or DistributionalForcing)
- `discount_rate`: Discount rate for NPV calculations

# Keyword Arguments
- `algorithm::Symbol=:NSGA2`: Metaheuristics algorithm (:NSGA2, :NSGA3, :SPEA2, :MOEAD)
- `max_iterations::Int=100`: Maximum optimization iterations
- `population_size::Int=50`: Population size
- `parallel::Bool=true`: Use parallel evaluation
- `seed::Int=42`: Random seed for reproducibility

# Returns
OptimizationResult with Pareto frontier (access via `pareto_front(result)`)
"""
function optimize(
    config::ICOWConfig{T},
    forcings::AbstractVector,
    discount_rate::Real;
    algorithm::Symbol=:NSGA2,
    max_iterations::Int=100,
    population_size::Int=50,
    parallel::Bool=true,
    seed::Int=42,
) where {T<:Real}
    # Create scenarios from forcings
    scenarios = _create_scenarios(forcings, discount_rate)

    # Create feasibility constraint
    constraint = _feasibility_constraint(config.city)

    # Create optimization problem
    prob = SimOptDecisions.OptimizationProblem(
        config,
        scenarios,
        StaticPolicy{T},
        _metric_calculator,
        [SimOptDecisions.minimize(:mean_investment), SimOptDecisions.minimize(:mean_damage)];
        constraints=SimOptDecisions.AbstractConstraint[constraint]
    )

    # Create backend
    backend = SimOptDecisions.MetaheuristicsBackend(;
        algorithm=algorithm,
        max_iterations=max_iterations,
        population_size=population_size,
        parallel=parallel,
    )

    # Run optimization
    Random.seed!(seed)
    return SimOptDecisions.optimize(prob, backend)
end

# Legacy wrapper for old API
function optimize(
    city::Core.CityParameters{T},
    forcings::AbstractVector,
    discount_rate::Real;
    kwargs...
) where {T<:Real}
    return optimize(ICOWConfig(city), forcings, discount_rate; kwargs...)
end

"""
    pareto_policies(result, ::Type{StaticPolicy{T}}) where {T}

Extract StaticPolicy instances from optimization result Pareto frontier.
Returns Vector of (policy, objectives) tuples.
"""
function pareto_policies(result, ::Type{StaticPolicy{T}}) where {T}
    policies = Tuple{StaticPolicy{T}, NamedTuple}[]
    for (params, objectives) in SimOptDecisions.pareto_front(result)
        policy = StaticPolicy{T}(T.(params))
        obj_tuple = (mean_investment=objectives[1], mean_damage=objectives[2])
        push!(policies, (policy, obj_tuple))
    end
    return policies
end

"""
    best_total(result, ::Type{StaticPolicy{T}}) where {T}

Extract the policy with minimum total cost (investment + damage) from Pareto frontier.
"""
function best_total(result, ::Type{StaticPolicy{T}}) where {T}
    best_policy = nothing
    best_total_cost = T(Inf)
    best_objectives = nothing

    for (params, objectives) in SimOptDecisions.pareto_front(result)
        total_cost = objectives[1] + objectives[2]  # investment + damage
        if total_cost < best_total_cost
            best_total_cost = total_cost
            best_policy = StaticPolicy{T}(T.(params))
            best_objectives = (mean_investment=objectives[1], mean_damage=objectives[2])
        end
    end

    return (best_policy, best_objectives)
end

"""
    valid_bounds(::Type{StaticPolicy}, city)

Return (lower, upper) bounds for StaticPolicy parameters [W, R, P, D, B].
City-specific bounds.
"""
function valid_bounds(::Type{StaticPolicy}, city::Core.CityParameters{T}) where {T<:Real}
    lower = (zero(T), zero(T), zero(T), zero(T), zero(T))
    upper = (city.H_city, city.H_city, T(0.99), city.H_city, city.H_city)
    return (lower, upper)
end
