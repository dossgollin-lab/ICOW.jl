# Optimization interface using Metaheuristics.jl
# See docs/roadmap/phase09_optimization.md

using Metaheuristics

"""
    OptimizationResult{T}

Result from multi-objective optimization.
"""
struct OptimizationResult{T<:Real}
    pareto_front::Matrix{T}  # [n_solutions x 2] objective values (cost, damage)
    pareto_set::Matrix{T}    # [n_solutions x n_params] parameter values
    n_evaluations::Int
end

# Large penalty for infeasible solutions (Metaheuristics doesn't handle Inf)
const INFEASIBLE_PENALTY = 1e20

"""
    make_objective(PolicyType, ensemble, discount_rate; aggregate=mean)

Create objective function for optimization. Returns f(θ) -> (cost, damage).
"""
function make_objective(
    ::Type{P},
    ensemble::Vector{<:Tuple{CityParameters,<:AbstractForcing}},
    discount_rate::Real;
    aggregate=mean
) where {P<:AbstractPolicy}

    function f(θ::AbstractVector{T}) where {T}
        # Reconstruct policy from parameters
        policy = try
            P(θ)
        catch
            # Return penalty with constraint violation
            return (T[INFEASIBLE_PENALTY, INFEASIBLE_PENALTY], T[INFEASIBLE_PENALTY], T[0])
        end

        # Evaluate over ensemble
        costs = Vector{T}(undef, length(ensemble))
        damages = Vector{T}(undef, length(ensemble))

        for (i, (city, forcing)) in enumerate(ensemble)
            # Check feasibility against this city
            if !is_feasible(policy.levers, city)
                return (T[INFEASIBLE_PENALTY, INFEASIBLE_PENALTY], T[INFEASIBLE_PENALTY], T[0])
            end

            # Run simulation in trace mode with safe=true
            trace = simulate(city, policy, forcing; mode=:trace, safe=true)

            # Check for simulation failure
            if isa(trace, Tuple) && length(trace) == 2 && isinf(trace[1])
                return (T[INFEASIBLE_PENALTY, INFEASIBLE_PENALTY], T[INFEASIBLE_PENALTY], T[0])
            end

            # Calculate NPV
            (npv_cost, npv_damage) = calculate_npv(trace, discount_rate)
            costs[i] = npv_cost
            damages[i] = npv_damage
        end

        # Return (objectives, inequality constraints, equality constraints)
        fx = T[aggregate(costs), aggregate(damages)]
        return (fx, T[0], T[0])
    end

    return f
end

"""
    optimize(PolicyType, ensemble, discount_rate; kwargs...)

Multi-objective optimization using NSGA-II. Returns Pareto front of cost vs damage.
"""
function optimize(
    ::Type{P},
    ensemble::Vector{<:Tuple{CityParameters,<:AbstractForcing}},
    discount_rate::Real;
    aggregate=mean,
    n_generations::Int=100,
    population_size::Int=100,
    seed::Union{Int,Nothing}=nothing
) where {P<:AbstractPolicy}

    # Get bounds from first ensemble member
    city = ensemble[1][1]
    (lb, ub) = bounds(P, city)

    # Create objective function
    f = make_objective(P, ensemble, discount_rate; aggregate=aggregate)

    # Configure NSGA-II
    options = Options(; iterations=n_generations, seed=seed)
    algo = NSGA2(; N=population_size, options=options)

    # Run optimization
    result = Metaheuristics.optimize(f, [lb ub], algo)

    # Extract non-dominated solutions from population
    non_dominated = filter(sol -> sol.rank == 1, result.population)

    # Convert to matrices
    n_solutions = length(non_dominated)
    n_params = length(lb)
    T = eltype(lb)

    front_matrix = Matrix{T}(undef, n_solutions, 2)
    set_matrix = Matrix{T}(undef, n_solutions, n_params)

    for (i, sol) in enumerate(non_dominated)
        front_matrix[i, :] = sol.f
        set_matrix[i, :] = sol.x
    end

    return OptimizationResult(
        front_matrix,
        set_matrix,
        result.f_calls
    )
end

"""
    optimize_scalar(PolicyType, ensemble, discount_rate; kwargs...)

Single-objective optimization minimizing total cost (investment + damage).
"""
function optimize_scalar(
    ::Type{P},
    ensemble::Vector{<:Tuple{CityParameters,<:AbstractForcing}},
    discount_rate::Real;
    aggregate=mean,
    n_generations::Int=100,
    population_size::Int=100,
    seed::Union{Int,Nothing}=nothing
) where {P<:AbstractPolicy}

    # Get bounds from first ensemble member
    city = ensemble[1][1]
    (lb, ub) = bounds(P, city)

    # Create bi-objective function and wrap to single objective
    f_bi = make_objective(P, ensemble, discount_rate; aggregate=aggregate)
    f(θ) = sum(f_bi(θ)[1])  # total cost = sum of objectives (f_bi returns (fx, gx, hx))

    # Configure DE (differential evolution) for single objective
    options = Options(; iterations=n_generations, seed=seed)
    algo = DE(; N=population_size, options=options)

    # Run optimization
    result = Metaheuristics.optimize(f, [lb ub], algo)

    # Return best solution as single-row OptimizationResult
    best = minimizer(result)
    best_fx = f_bi(best)[1]  # extract objectives from (fx, gx, hx)

    return OptimizationResult(
        reshape(best_fx, 1, 2),
        reshape(best, 1, length(best)),
        result.iteration * population_size
    )
end
