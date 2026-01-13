# ICOW.jl SimOptDecisions Integration Roadmap

This file tracks progress on integrating ICOW.jl with SimOptDecisions.
Check off items as they are completed using `[x]`.

## Instructions

1. Work through phases in order (A through F)
2. Mark items complete with `[x]` as you finish them
3. Each phase should pass tests before moving to the next
4. Run `julia --project test/runtests.jl` after each phase

---

## Phase A: Add Dependencies

- [x] Add SimOptDecisions to Project.toml via HTTPS URL
  - URL: `https://github.com/dossgollin-lab/SimOptDecisions`
- [x] Add Metaheuristics to Project.toml
- [x] Remove BlackBoxOptim from Project.toml
- [x] Verify: `using ICOW` loads without errors

---

## Phase B: Update Types for SimOptDecisions

### B1: Module Setup

- [x] Add `using SimOptDecisions` to `src/ICOW.jl`

### B2: Update Abstract Types (src/types.jl)

- [x] Remove `abstract type AbstractForcing{T<:Real} end`
- [x] Remove `abstract type AbstractSimulationState{T<:Real} end`
- [x] Remove `abstract type AbstractPolicy{T<:Real} end`
- [x] Make `Levers{T} <: SimOptDecisions.AbstractAction`

### B3: Update CityParameters (src/parameters.jl)

- [x] Make `CityParameters{T} <: SimOptDecisions.AbstractConfig`

### B4: Update State (src/states.jl)

- [x] Make `State{T} <: SimOptDecisions.AbstractState`

### B5: Create SOW Wrappers (src/forcing.jl)

- [x] Create `EADSOW{T,D} <: SimOptDecisions.AbstractSOW`
  - Fields: forcing, discount_rate, method
- [x] Create `StochasticSOW{T} <: SimOptDecisions.AbstractSOW`
  - Fields: forcing, scenario, discount_rate
- [x] Add helper functions: `n_years(sow)`, `get_surge(sow, year)`

### B6: Update Policy (src/policies.jl)

- [x] Make `StaticPolicy{T} <: SimOptDecisions.AbstractPolicy`
- [x] Rename `parameters()` to `SimOptDecisions.params()`
- [x] Add `SimOptDecisions.param_bounds(::Type{StaticPolicy{T}})`
- [x] Keep `valid_bounds()` for backward compatibility

### B7: Update Exports (src/ICOW.jl)

- [x] Export `EADSOW`, `StochasticSOW`
- [x] Remove exports of deleted abstract types

### B8: Verify

- [x] All existing tests pass

---

## Phase C: Implement EAD Simulation

### C1: Add SimOptDecisions.simulate for EADSOW (src/simulation.jl)

- [x] Create `SimOptDecisions.simulate(config::CityParameters, sow::EADSOW, policy, recorder, rng)`
- [x] Reuse `_simulate_core` logic with EAD damage function
- [x] Return NamedTuple: `(investment=..., damage=...)`

### C2: Add get_action for EADSOW (src/policies.jl)

- [x] Create `SimOptDecisions.get_action(policy::StaticPolicy, state, sow::EADSOW, t::TimeStep)`

### C3: Add backward-compatible wrapper (src/simulation.jl)

- [x] Keep `simulate(city, policy, forcing::DistributionalForcing; ...)` signature
- [x] Have it construct EADSOW and call SimOptDecisions.simulate

### C4: Verify

- [x] EAD simulation tests pass
- [x] `simulate(city, policy, dist_forcing)` still works

---

## Phase D: Implement Stochastic Simulation

### D1: Add SimOptDecisions.simulate for StochasticSOW (src/simulation.jl)

- [x] Create `SimOptDecisions.simulate(config::CityParameters, sow::StochasticSOW, policy, recorder, rng)`
- [x] Use stochastic damage calculation

### D2: Add get_action for StochasticSOW (src/policies.jl)

- [x] Create `SimOptDecisions.get_action(policy::StaticPolicy, state, sow::StochasticSOW, t::TimeStep)`

### D3: Add backward-compatible wrapper (src/simulation.jl)

- [x] Keep `simulate(city, policy, forcing::StochasticForcing; ...)` signature
- [x] Have it construct StochasticSOW and call SimOptDecisions.simulate

### D4: Verify

- [x] Stochastic simulation tests pass
- [x] `simulate(city, policy, stoch_forcing)` still works
- [ ] Mode convergence: mean(stochastic) $\approx$ EAD

---

## Phase E: Replace Optimization

### E1: Rewrite optimization.jl

- [x] Remove `using BlackBoxOptim`
- [x] Add `using SimOptDecisions: OptimizationProblem, MetaheuristicsBackend, ...`
- [x] Create helper `_create_sows(forcings, discount_rate)`
- [x] Create `metric_calculator` function
- [x] Create `FeasibilityConstraint` for lever feasibility
- [x] Implement new `optimize()` using `OptimizationProblem` and `MetaheuristicsBackend`
- [x] Implement new `pareto_policies()` using `pareto_front()`

### E2: Verify

- [x] Optimization runs without error
- [x] Returns valid Pareto frontier
- [x] Feasibility constraint enforced

---

## Phase F: Cleanup

### F1: Remove deprecated files

- [x] Delete `docs/roadmap/` directory
- [x] Delete `tasks/` directory

### F2: Final verification

- [x] Full test suite passes: `julia --project test/runtests.jl`
- [x] C++ validation passes: `julia --project test/cpp_reference/validate_cpp_outputs.jl`
- [x] No BlackBoxOptim references remain in codebase

---

## Quick Reference: File Changes

| File | Action |
|------|--------|
| Project.toml | Add SimOptDecisions (SSH), Metaheuristics; remove BlackBoxOptim |
| src/ICOW.jl | Add `using SimOptDecisions`, update exports |
| src/types.jl | Remove old abstracts, `Levers <: AbstractAction` |
| src/parameters.jl | `CityParameters <: AbstractConfig` |
| src/states.jl | `State <: AbstractState` |
| src/forcing.jl | Add `EADSOW`, `StochasticSOW` |
| src/policies.jl | `StaticPolicy <: AbstractPolicy`, add `params`/`param_bounds`/`get_action` |
| src/simulation.jl | Add SimOptDecisions.simulate methods, keep backward-compat wrappers |
| src/optimization.jl | Complete rewrite using SimOptDecisions |

---

## Preserved (Do Not Modify)

These files contain physics that must remain unchanged:

- src/geometry.jl
- src/costs.jl
- src/damage.jl
- src/zones.jl
- src/objectives.jl
- test/cpp_reference/validate_cpp_outputs.jl
