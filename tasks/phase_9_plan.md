# Phase 9: Optimization - Implementation Plan

**Status:** Completed

## Summary

Implement simulation-optimization interface using BlackBoxOptim.jl for multi-objective optimization of policy parameters.

## Context

The codebase already has:

- `simulate()` supporting both stochastic and EAD modes
- `objectives.jl` with `apply_discount()`, `calculate_npv()`, and `objective_total_cost()`
- `StaticPolicy` with `parameters()` extraction and reconstruction from vector
- BlackBoxOptim already in Project.toml

## Implementation Tasks

### Task 1: Add `discount_rate` to `simulate()`

Modify both simulation modes to accept optional `discount_rate` parameter that applies discounting within the loop.

**Changes to `src/simulation.jl`:**

- Add `discount_rate::Real=0.0` parameter to both `simulate()` signatures
- Pass through to internal implementations
- Apply discounting in the accumulation step (not to individual yearly costs, but accumulate discounted values)
- When `discount_rate > 0`, return values are NPV

**Rationale:** The roadmap specifies discounting should happen in simulation, not objectives.jl. This makes scalar mode useful for optimization (returns NPV directly without needing trace mode).

- [x] Add parameter to `simulate()` for `StochasticForcing`
- [x] Add parameter to `simulate()` for `DistributionalForcing`
- [x] Update `_simulate_stochastic()` to apply discounting
- [x] Update `_simulate_ead()` to apply discounting

### Task 2: Add `valid_bounds()` to policies

**Changes to `src/policies.jl`:**

- Add `valid_bounds(::Type{StaticPolicy}, city)` function
- Returns `(lower, upper)` tuples for the 5 parameters [W, R, P, D, B]

**Bounds for StaticPolicy:**

- W: `[0, H_city]` - withdrawal height
- R: `[0, H_city]` - resistance height
- P: `[0, 0.99]` - resistance percentage (not 1.0 to avoid edge cases)
- D: `[0, H_city]` - dike height
- B: `[0, H_city]` - dike base elevation

- [x] Add `valid_bounds()` function
- [x] Export from ICOW.jl

### Task 3: Create `src/optimization.jl`

Thin wrapper around BlackBoxOptim:

- [x] Create `optimize()` function that:
  - Takes city, forcings (vector), discount_rate
  - Optional: policy_type, aggregator function, max_steps, population_size
  - Uses `valid_bounds()` to get search range
  - Wraps simulation as objective function returning `(investment, damage)` tuple
  - Aggregates across SOWs using provided function (default: mean)
  - Runs `bboptimize` with `:borg_moea` method for multi-objective

- [x] Add `pareto_policies()` helper to extract policies from Pareto frontier
- [x] Add `best_total()` helper to extract policy minimizing total cost

### Task 4: Update exports

**Changes to `src/ICOW.jl`:**

- [x] Add `include("optimization.jl")` (after objectives.jl)
- [x] Export `valid_bounds`
- [x] Export `optimize`, `pareto_policies`, `best_total`

### Task 5: Create tests

**Create `test/optimization_tests.jl`:**

- [x] Test `valid_bounds` returns correct structure
- [x] Test bounds are valid (lower <= upper)
- [x] Test short optimization runs without error
- [x] Test Pareto frontier is non-empty

- [x] Update `test/runtests.jl` to include optimization tests

### Task 6: Run full test suite

- [x] Run `julia --project test/runtests.jl`
- [x] All 245 tests pass

## Design Decisions (from roadmap)

1. **Bounds live in policies** - `valid_bounds(PolicyType, city)` not separate types
2. **Discount in simulation** - not objectives.jl or optimization.jl
3. **Minimal wrapper** - just translates between simulation and BlackBoxOptim
4. **No aggregator types** - just pass a function like `mean` or `x -> quantile(x, 0.95)`
5. **Simple infeasibility handling** - Check `is_feasible()` before simulation, return `(Inf, Inf)` if infeasible. No `safe=true` complexity.

## Review

### Changes Made

1. **`src/simulation.jl`**: Added `discount_rate::Real=0.0` parameter to both `simulate()` methods. Discounting is applied during accumulation in both `_simulate_stochastic()` and `_simulate_ead()`. Removed `safe=true` parameter (simplified as requested).

2. **`src/policies.jl`**: Added `valid_bounds(::Type{StaticPolicy}, city)` function returning bounds tuples for the 5 lever parameters.

3. **`src/optimization.jl`**: New file with:
   - `optimize()` - thin wrapper around BlackBoxOptim with `:borg_moea` method
   - `pareto_policies()` - extract policies from Pareto frontier
   - `best_total()` - extract policy minimizing total cost

4. **`src/ICOW.jl`**: Added include and exports for optimization module.

5. **`test/optimization_tests.jl`**: Tests for `valid_bounds`, short optimization run, and discount_rate behavior.

### Notes

- BlackBoxOptim warnings about epsilon-box clamping are expected with large objective values (billions in city damage) - does not affect correctness
- Trace mode still stores undiscounted values for analysis; only scalar mode returns discounted NPV
- `safe=true` was removed per user request - infeasibility is handled via `is_feasible()` check returning `(Inf, Inf)`
