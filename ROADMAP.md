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

- [ ] Add SimOptDecisions to Project.toml via HTTPS URL
  - URL: `https://github.com/dossgollin-lab/SimOptDecisions`
- [ ] Add Metaheuristics to Project.toml
- [ ] Remove BlackBoxOptim from Project.toml
- [ ] Verify: `using ICOW` loads without errors

---

## Phase B: Update Types for SimOptDecisions

### B1: Module Setup

- [ ] Add `using SimOptDecisions` to `src/ICOW.jl`

### B2: Update Abstract Types (src/types.jl)

- [ ] Remove `abstract type AbstractForcing{T<:Real} end`
- [ ] Remove `abstract type AbstractSimulationState{T<:Real} end`
- [ ] Remove `abstract type AbstractPolicy{T<:Real} end`
- [ ] Make `Levers{T} <: SimOptDecisions.AbstractAction`

### B3: Update CityParameters (src/parameters.jl)

- [ ] Make `CityParameters{T} <: SimOptDecisions.AbstractConfig`

### B4: Update State (src/states.jl)

- [ ] Make `State{T} <: SimOptDecisions.AbstractState`

### B5: Create SOW Wrappers (src/forcing.jl)

- [ ] Create `EADSOW{T,D} <: SimOptDecisions.AbstractSOW`
  - Fields: forcing, discount_rate, method
- [ ] Create `StochasticSOW{T} <: SimOptDecisions.AbstractSOW`
  - Fields: forcing, scenario, discount_rate
- [ ] Add helper functions: `n_years(sow)`, `get_surge(sow, year)`

### B6: Update Policy (src/policies.jl)

- [ ] Make `StaticPolicy{T} <: SimOptDecisions.AbstractPolicy`
- [ ] Rename `parameters()` to `SimOptDecisions.params()`
- [ ] Add `SimOptDecisions.param_bounds(::Type{StaticPolicy{T}})`
- [ ] Keep `valid_bounds()` for backward compatibility

### B7: Update Exports (src/ICOW.jl)

- [ ] Export `EADSOW`, `StochasticSOW`
- [ ] Remove exports of deleted abstract types

### B8: Verify

- [ ] All existing tests pass

---

## Phase C: Implement EAD Simulation

### C1: Add SimOptDecisions.simulate for EADSOW (src/simulation.jl)

- [ ] Create `SimOptDecisions.simulate(config::CityParameters, sow::EADSOW, policy, recorder, rng)`
- [ ] Reuse `_simulate_core` logic with EAD damage function
- [ ] Return NamedTuple: `(investment=..., damage=...)`

### C2: Add get_action for EADSOW (src/policies.jl)

- [ ] Create `SimOptDecisions.get_action(policy::StaticPolicy, state, sow::EADSOW, t::TimeStep)`

### C3: Add backward-compatible wrapper (src/simulation.jl)

- [ ] Keep `simulate(city, policy, forcing::DistributionalForcing; ...)` signature
- [ ] Have it construct EADSOW and call SimOptDecisions.simulate

### C4: Verify

- [ ] EAD simulation tests pass
- [ ] `simulate(city, policy, dist_forcing)` still works

---

## Phase D: Implement Stochastic Simulation

### D1: Add SimOptDecisions.simulate for StochasticSOW (src/simulation.jl)

- [ ] Create `SimOptDecisions.simulate(config::CityParameters, sow::StochasticSOW, policy, recorder, rng)`
- [ ] Use stochastic damage calculation

### D2: Add get_action for StochasticSOW (src/policies.jl)

- [ ] Create `SimOptDecisions.get_action(policy::StaticPolicy, state, sow::StochasticSOW, t::TimeStep)`

### D3: Add backward-compatible wrapper (src/simulation.jl)

- [ ] Keep `simulate(city, policy, forcing::StochasticForcing; ...)` signature
- [ ] Have it construct StochasticSOW and call SimOptDecisions.simulate

### D4: Verify

- [ ] Stochastic simulation tests pass
- [ ] `simulate(city, policy, stoch_forcing)` still works
- [ ] Mode convergence: mean(stochastic) $\approx$ EAD

---

## Phase E: Replace Optimization

### E1: Rewrite optimization.jl

- [ ] Remove `using BlackBoxOptim`
- [ ] Add `using SimOptDecisions: OptimizationProblem, MetaheuristicsBackend, ...`
- [ ] Create helper `_create_sows(forcings, discount_rate)`
- [ ] Create `metric_calculator` function
- [ ] Create `FeasibilityConstraint` for lever feasibility
- [ ] Implement new `optimize()` using `OptimizationProblem` and `MetaheuristicsBackend`
- [ ] Implement new `pareto_policies()` using `pareto_front()`

### E2: Verify

- [ ] Optimization runs without error
- [ ] Returns valid Pareto frontier
- [ ] Feasibility constraint enforced

---

## Phase F: Cleanup

### F1: Remove deprecated files

- [x] Delete `docs/roadmap/` directory
- [x] Delete `tasks/` directory

### F2: Final verification

- [ ] Full test suite passes: `julia --project test/runtests.jl`
- [ ] C++ validation passes: `julia --project test/cpp_reference/validate_cpp_outputs.jl`
- [ ] No BlackBoxOptim references remain in codebase

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
