# Phase 9: Optimization

**Status:** Completed

**Prerequisites:** Phase 8 (Policies)

## Goal

Simulation-optimization interface using BlackBoxOptim.jl (general-purpose, multi-objective).

## Approach

This is **simulation-optimization**.

The **system model** handles all discounting and returns a set of **metrics** for each state of the world it's simulated against.
This gives us a vector of performance metrics for each SOW.

We need to tell the optimizer:

- Which SOWs we want to optimize over
- How to combine them (default to mean, allow other options like `x -> quantile(x, 0.95)`)
- How to weight them (default to equal weight)
- Which metrics we want to keep and whether we want to minimize or maximize them

Each policy will have its own unique parameters that need to be optimized, so we need to hook closely there.
Additionally, each policy will have unique ranges of valid parameters.
We address this by having `valid_bounds` defined for each policy when we define the policy to give us a bounding box, and we check for a valid *combination* of policy parameters at each simulation and return Inf if invalid.

## Implementation Details

### Step 1: Add `discount_rate` to simulation

Modify `simulate()` to accept optional `discount_rate` parameter.

```julia
function simulate(
    city::CityParameters{T},
    policy::AbstractPolicy{T},
    forcing::AbstractForcing;
    mode::Symbol=:scalar,
    discount_rate::Real=0.0,  # NEW: 0.0 means no discounting
    ...
) where {T<:Real}
```

In the time-stepping loop, apply discount before accumulating:

```julia
# Inside loop at year t
discounted_cost = apply_discount(cost, year, discount_rate)
discounted_damage = apply_discount(damage, year, discount_rate)
# Accumulate discounted values
```

Return values are now NPV when `discount_rate > 0`.

### Step 2: Add `valid_bounds()` to policies

Each policy defines bounds for its parameters.

```julia
# In src/policies.jl

"""
    valid_bounds(::Type{StaticPolicy}, city::CityParameters)

Return (lower, upper) bounds for StaticPolicy parameters [W, R, P, D, B].
"""
function valid_bounds(::Type{StaticPolicy}, city::CityParameters{T}) where {T<:Real}
    lower = (zero(T), zero(T), zero(T), zero(T), zero(T))
    upper = (city.H_city, city.H_city, T(0.99), city.H_city, city.H_city)
    return (lower, upper)
end
```

### Step 3: Create `src/optimization.jl`

Thin wrapper that:

1. Takes policy type + bounds from `valid_bounds`
2. Wraps simulation to return tuple for BlackBoxOptim
3. Aggregates across SOWs using user-provided function

```julia
# src/optimization.jl

using BlackBoxOptim

"""
    optimize(
        city, forcings, discount_rate;
        policy_type = StaticPolicy,
        aggregator = mean,
        max_steps = 10000,
        kwargs...
    )

Multi-objective optimization using BlackBoxOptim.
"""
function optimize(
    city::CityParameters{T},
    forcings::Vector{<:AbstractForcing},
    discount_rate::Real;
    policy_type::Type{<:AbstractPolicy} = StaticPolicy,
    aggregator::Function = mean,
    max_steps::Int = 10000,
    population_size::Int = 100,
    kwargs...
) where {T<:Real}

    # Get bounds from policy
    (lower, upper) = valid_bounds(policy_type, city)
    search_range = [(lower[i], upper[i]) for i in eachindex(lower)]

    # Objective function: params -> (investment, damage)
    function objective(params)
        # Reconstruct policy
        policy = try
            policy_type(params)
        catch
            return (T(Inf), T(Inf))
        end

        # Check feasibility
        if !is_feasible(policy.levers, city)
            return (T(Inf), T(Inf))
        end

        # Simulate across all SOWs
        investments = T[]
        damages = T[]
        for forcing in forcings
            (inv, dmg) = simulate(city, policy, forcing;
                                   mode=:scalar, discount_rate=discount_rate, safe=true)
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
        Method = :borg_moea,
        FitnessScheme = ParetoFitnessScheme{2}(is_minimizing=true),
        SearchRange = search_range,
        NumDimensions = length(lower),
        MaxSteps = max_steps,
        PopulationSize = population_size,
        TraceMode = :silent,
        kwargs...
    )

    return result
end

# Convenience helpers for extracting results
pareto_policies(result, policy_type) = [policy_type(params(p)) for p in pareto_frontier(result)]
best_total(result, policy_type) = policy_type(best_candidate(result))
```

### Step 4: Update exports

```julia
# In src/ICOW.jl
using BlackBoxOptim

include("optimization.jl")

export valid_bounds
export optimize, pareto_policies, best_total
```

## Testing

```julia
@testset "Optimization" begin
    city = CityParameters()
    forcing = DistributionalForcing([Normal(1.5, 0.5) for _ in 1:5], 2020)

    # valid_bounds returns correct structure
    (lower, upper) = valid_bounds(StaticPolicy, city)
    @test length(lower) == 5
    @test all(lower .<= upper)

    # Short optimization runs without error
    result = optimize(city, [forcing], 0.03; max_steps=50, population_size=10)
    @test !isempty(pareto_frontier(result))
end
```

## Checklist

- [x] Add `discount_rate` to `simulate()` (both modes)
- [x] Add `valid_bounds(::Type{StaticPolicy}, city)`
- [x] Create `src/optimization.jl` with `optimize()`
- [x] Add exports to `src/ICOW.jl`
- [x] Create `test/optimization_tests.jl`
- [x] Run tests (245 pass)

## Key Design Decisions

1. **Bounds live in policies** - `valid_bounds(PolicyType, city)` not separate types
2. **Discount in simulation** - not objectives.jl or optimization.jl
3. **Minimal wrapper** - just translates between simulation and BlackBoxOptim
4. **No aggregator types** - just pass a function like `mean` or `x -> quantile(x, 0.95)`
