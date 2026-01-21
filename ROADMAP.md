# ICOW.jl Refactoring Roadmap

Major refactor to align with SimOptDecisions v0.2 5-callback interface.

## Overview

SimOptDecisions has breaking changes requiring ICOW to migrate from a monolithic `simulate()` override to implementing 5 callbacks.

### Key Design Changes

1. **State**: Remove `current_year`, add `current_sea_level`
2. **Scenario**: Add sea-level time series (constant for now, SLR-ready)
3. **Simulation**: Implement 5-callback pattern instead of monolithic `simulate()`
4. **Type Names**: `EADSOW` $\to$ `EADScenario`, `StochasticSOW` $\to$ `StochasticScenario`

---

## Phase 1: Type Hierarchy Updates

**Files:** `src/forcing.jl`, `src/states.jl`

- [x] Rename `EADSOW` to `EADScenario` (inherit from `AbstractScenario`)
- [x] Rename `StochasticSOW` to `StochasticScenario` (inherit from `AbstractScenario`)
- [x] Add `sea_level::T` field to both scenario types (constant for now, SLR-ready)
- [x] Add `get_sea_level(scenario, year)` accessor function
- [x] Update `State` struct:
  - [x] Remove `current_year::Int`
  - [x] Add `current_sea_level::T`
- [x] Update `State` constructor to take initial sea level

---

## Phase 2: Implement 5-Callback Interface

**File:** `src/simulation.jl` (major rewrite)

### Callback 1: `initialize`

- [x] `SimOptDecisions.initialize(config::CityParameters, scenario::EADScenario, rng)` $\to$ `State`
- [x] `SimOptDecisions.initialize(config::CityParameters, scenario::StochasticScenario, rng)` $\to$ `State`
- [x] Initialize with zero levers and initial sea level from scenario

### Callback 2: `time_axis`

- [x] `SimOptDecisions.time_axis(config::CityParameters, scenario::EADScenario)` $\to$ `1:n_years`
- [x] `SimOptDecisions.time_axis(config::CityParameters, scenario::StochasticScenario)` $\to$ `1:n_years`

### Callback 3: `get_action`

- [x] Update signature: `get_action(policy, state, t::TimeStep, scenario)` (reordered args)
- [x] Keep in `policies.jl`

### Callback 4: `run_timestep`

- [x] `SimOptDecisions.run_timestep(state, action, t, config, scenario, rng)` $\to$ `(new_state, step_record)`
- [x] Enforce irreversibility: `new_levers = max(state.current_levers, action)`
- [x] Compute marginal investment cost (delta from previous levers)
- [x] Compute damage (EAD or stochastic depending on scenario type)
- [x] Update sea level from scenario time series
- [x] Return `step_record` as NamedTuple: `(investment=..., damage=...)`

### Callback 5: `compute_outcome`

- [x] `SimOptDecisions.compute_outcome(step_records, config, scenario)` $\to$ `(investment=..., damage=...)`
- [x] Apply discounting here (NPV calculation)
- [x] Sum discounted investment and damage across all years

---

## Phase 3: Update Policy Interface

**File:** `src/policies.jl`

- [x] Update `get_action` signature to new order: `(policy, state, t::TimeStep, scenario)`
- [x] Remove any SOW references, use scenario
- [x] Keep `params()` and `param_bounds()` unchanged (still needed for optimization)

---

## Phase 4: Update Optimization

**File:** `src/optimization.jl`

- [x] Rename `_create_sows()` to `_create_scenarios()`
- [x] Update to create `EADScenario`/`StochasticScenario` instead of SOW types
- [x] Update `OptimizationProblem` construction
- [x] Use `FeasibilityConstraint` for lever validity (kept existing approach)

---

## Phase 5: Backward Compatibility

**File:** `src/simulation.jl`

- [x] Keep wrapper functions: `simulate(city, policy, forcing::StochasticForcing; ...)`
- [x] These internally create scenarios and call `SimOptDecisions.simulate()`
- [x] Maintain existing return type `(investment=..., damage=...)`

---

## Phase 6: Remove Dead Code

- [x] Delete old monolithic `SimOptDecisions.simulate()` implementations
- [x] Remove `current_year` references throughout source code
- [x] No deprecated SOW type aliases needed

---

## Phase 7: Update Tests

**Files:** `test/*_tests.jl`

- [x] Update `states_tests.jl` for new State fields
- [ ] Update `forcing_tests.jl` for new scenario types (if needed)
- [ ] Update `simulation_tests.jl` for new callback interface (if needed)
- [ ] Update `optimization_tests.jl` for scenario types (if needed)
- [ ] Update `policies_tests.jl` for new `get_action` signature (if needed)
- [ ] Run C++ validation suite

---

## Phase 8: Update Documentation

**Files:** `docs/examples/*.qmd`

- [ ] Update example code to use new type names
- [ ] Update any simulation examples
- [ ] Verify docs build cleanly

---

## Dependency Update Required

**CRITICAL:** ICOW.jl's `Project.toml` must be updated to use the new SimOptDecisions with the 5-callback interface.

Run:

```julia
using Pkg
Pkg.update("SimOptDecisions")
```

---

## Design Decisions

### Discounting

Apply discount factor in `compute_outcome()`, not per-timestep.
This keeps `step_records` as raw annual values, making debugging easier.

### Feasibility

Use `FeasibilityConstraint` in optimization.
Simulation no longer returns `(Inf, Inf)` for infeasible levers.

### Sea Level

- For now: constant sea level (e.g., 0.0m baseline)
- Future: `TimeSeriesParameter` allows year-indexed SLR projections
- State tracks `current_sea_level` which updates each timestep from scenario

### Type Aliases

Clean break - no deprecated aliases.
This is a major version bump anyway.
