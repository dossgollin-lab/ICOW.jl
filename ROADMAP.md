# ICOW Development Roadmap

## Status

| Phase | Status | Notes |
|-------|--------|-------|
| 1. Core Pure Functions | Complete | Types moved to src/types.jl, Core exports only functions |
| 2. Shared Types Module | Not Started | |
| 3. Stochastic Submodule | Not Started | |
| 4. EAD Submodule | Not Started | |
| 5. Cleanup | Not Started | Old test files need cleanup (pre-existing) |
| 6. Documentation | Not Started | |

**Current Phase:** 2 (Shared Types Module)

**Blocking Issues:** None

## Process Rules

### Deviations from Plan

Any deviation from this plan requires:

1. **User approval** before implementation
2. **Documentation** of the deviation and rationale in this file
3. **Update** to affected phase tasks

Do NOT make changes that deviate from this plan without explicit user consent.

### Ambiguity

If ANY ambiguity arises during implementation:

1. **STOP** immediately
2. **ASK** the user for clarification
3. **DOCUMENT** the resolution in this file

Do NOT guess or make assumptions. Always ask.

### Checkboxes

Use checkboxes thoroughly:

- `[ ]` = not started
- `[x]` = complete
- `[~]` = partially complete (add note explaining what remains)

Update checkboxes as work progresses. Each task should be atomic enough that it's clearly done or not done.

### Update CLAUDE.md

At the end of each phase, update `CLAUDE.md` to reflect:

- Changes to file/directory structure (Current Architecture section)
- New coding patterns or conventions discovered
- Any lessons learned during implementation

### Understanding Current Behavior

Before modifying any code, consult these references:

| Topic | Primary Source | Secondary Source |
|-------|----------------|------------------|
| Mathematical formulas | `_background/equations.md` | Paper (Ceres et al. 2019) |
| C++ reference behavior | `_background/iCOW_2018_06_11.cpp` | `test/validation/cpp_reference/` |
| Current Julia implementation | `src/` files | Existing tests in `test/` |
| SimOptDecisions API | `_background/simoptdecisions_api.md` | SimOptDecisions package source |
| Project guidelines | `CLAUDE.md` | This file |

### Lessons Learned

Document lessons here for later addition to `CLAUDE.md`:

1. *(none yet)*

---

## Overview

Reorganize ICOW into a clean architecture:

1. **Core** = pure functions only (no structs), syntax matches equations.md
2. **Main ICOW module** = shared user-facing types (Levers, CityParameters, Zone)
3. **Stochastic submodule** = SimOptDecisions for discrete event simulation
4. **EAD submodule** = SimOptDecisions for expected annual damage integration

## Design Decisions

### Core Functions

Pure functions with individual numeric parameters matching equations.md:

```julia
# Core function - matches paper notation
Core.dike_volume(H_city, D_city, D_startup, s_dike, w_d, W_city, D)

# Wrapper provides convenience (in main module)
calculate_dike_volume(city::CityParameters, D)
```

### Stochastic vs EAD Mode

| Aspect | Stochastic | EAD |
|--------|------------|-----|
| Input forcing | Time series of surge heights | GEV parameters per year |
| Dike failure | Sampled (yes/no per event) | Integrated over probability |
| Damage output | Realized damage | Expected damage |
| Use case | Monte Carlo ensemble | Analytical optimization |

### State

State tracks current zones (derived from lever decisions + city params).
Zones directly feed damage calculations.
Irreversibility: zone boundaries can only increase (protection grows monotonically).

### Dike Failure

Per-event stochastic sampling (current behavior).
No persistent damage state - repair costs are implicit in damage factors.
Document: `f_failed = 1.5` includes conceptual repair/reconstruction costs.

### Submodule Independence

- `StaticPolicy` duplicated in each submodule (different state/scenario spaces)
- Separate `optimize()` functions per submodule
- Scenarios ARE forcing (no separate Forcing types)

## Target Architecture

```
src/
├── ICOW.jl              # Main module: re-exports, shared types
├── Core/
│   ├── Core.jl          # Pure functions only (no structs)
│   ├── geometry.jl      # dike_volume(H_city, D_city, ...)
│   ├── costs.jl         # withdrawal_cost, resistance_cost, dike_cost, ...
│   ├── zones.jl         # zone_boundaries, zone_values
│   └── damage.jl        # base_zone_damage, zone_damage, total_event_damage, ...
├── types.jl             # Levers, CityParameters, Zone (user-facing structs)
├── wrappers.jl          # Convenience functions calling Core with struct params
├── Stochastic/
│   ├── Stochastic.jl    # Submodule for discrete event simulation
│   ├── scenario.jl      # StochasticScenario (surge time series + discount rate)
│   ├── config.jl        # StochasticConfig wrapping CityParameters
│   ├── state.jl         # StochasticState (current zones)
│   ├── policy.jl        # StaticPolicy
│   ├── outcome.jl       # StochasticOutcome
│   ├── simulation.jl    # 5 SimOptDecisions callbacks (samples dike failure)
│   └── optimization.jl  # optimize() for stochastic mode
└── EAD/
    ├── EAD.jl           # Submodule for expected annual damage
    ├── scenario.jl      # EADScenario (GEV params per year + discount rate)
    ├── config.jl        # EADConfig wrapping CityParameters
    ├── state.jl         # EADState (current zones)
    ├── policy.jl        # StaticPolicy
    ├── outcome.jl       # EADOutcome
    ├── simulation.jl    # 5 SimOptDecisions callbacks (integrates over distributions)
    └── optimization.jl  # optimize() for EAD mode

test/
├── core/                # Pure function tests
│   ├── geometry_tests.jl
│   ├── costs_tests.jl
│   ├── zones_tests.jl
│   └── damage_tests.jl
├── shared/              # Shared types and wrapper tests
│   ├── types_tests.jl
│   └── wrappers_tests.jl
├── stochastic/          # Stochastic mode tests
│   ├── scenario_tests.jl
│   ├── simulation_tests.jl
│   └── optimization_tests.jl
└── ead/                 # EAD mode tests
    ├── scenario_tests.jl
    ├── simulation_tests.jl
    └── optimization_tests.jl
```

---

## Phase 1: Refactor Core to Pure Functions

**Goal:** Core contains only pure numeric functions, no structs.

**Status:** Complete

**Reference files:**

- Core: `src/Core/Core.jl` (pure functions only)
- Types: `src/types.jl` (Levers, CityParameters)

### Completed Tasks

- [x] Create `src/Core/Core.jl` submodule structure
- [x] Implement `geometry.jl` with `dike_volume(H_city, D_city, D_startup, s_dike, w_d, W_city, D)`
- [x] Implement `costs.jl` with:
  - [x] `withdrawal_cost(V_city, H_city, f_w, W)`
  - [x] `value_after_withdrawal(V_city, H_city, f_l, W)`
  - [x] `resistance_cost_fraction(f_adj, f_lin, f_exp, t_exp, P)`
  - [x] `resistance_cost(V_w, f_cR, H_bldg, H_city, W, R, B, b_basement)`
  - [x] `dike_cost(V_dike, c_d)`
  - [x] `effective_surge(h_raw, H_seawall, f_runup)`
  - [x] `dike_failure_probability(h_surge, D, t_fail, p_min)`
- [x] Implement `zones.jl` with:
  - [x] `zone_boundaries(H_city, W, R, B, D)` → tuple of 10 boundary values
  - [x] `zone_values(V_w, H_city, W, R, B, D, r_prot, r_unprot)` → tuple of 5 values
- [x] Implement `damage.jl` with:
  - [x] `base_zone_damage(z_low, z_high, value, h_surge, b_basement, H_bldg, f_damage)`
  - [x] `zone_damage(zone_idx, z_low, z_high, value, h_surge, ...)`
  - [x] `total_event_damage(bounds, values, h_surge, ...)`
  - [x] `expected_damage_given_surge(h_raw, bounds, values, ...)`
- [x] C++ validation passes (`test/validation/cpp_reference/validate_cpp_outputs.jl`)

### Remaining Tasks

- [x] Move `Levers{T}` struct from `src/Core/types.jl` to `src/types.jl`
  - Copy struct definition and constructor
  - Copy `is_feasible` function
  - Copy `Base.max` method for irreversibility
- [x] Move `CityParameters{T}` struct from `src/Core/types.jl` to `src/types.jl`
  - Copy struct definition with all fields and defaults
  - Copy `validate_parameters` function
- [x] Delete `src/Core/types.jl`
- [x] Update `src/Core/Core.jl`:
  - Remove `include("types.jl")`
  - Remove type exports (`Levers`, `CityParameters`, `validate_parameters`, `is_feasible`)
  - Keep only function exports
- [x] Update `src/ICOW.jl` to include new `src/types.jl`
- [x] Verify Core functions still work (they take individual params, not structs)
- [x] Run C++ validation to confirm no regression

### Validation Criteria

- [x] `Core` module exports ONLY functions, no types
- [x] `src/types.jl` contains `Levers` and `CityParameters`
- [x] C++ validation passes
- [x] Package loads without error: `using ICOW`

---

## Phase 2: Create Shared Types Module

**Goal:** User-facing structs and convenience wrappers in main module.

**Status:** Not Started

**Depends on:** Phase 1 complete

**Reference files:**

- Current types: `src/types.jl` (moved from Core in Phase 1)
- Zone definitions: `_background/equations.md` (Zone Definitions section)
- Wrapper targets: `src/Core/*.jl` functions

### Tasks

#### Types (`src/types.jl`)

- [ ] `Levers{T}` struct (moved from Phase 1):
  - Fields: `W`, `R`, `P`, `D`, `B`
  - Constructor with constraint validation
  - `Base.max(a::Levers, b::Levers)` for irreversibility
- [ ] `CityParameters{T}` struct (moved from Phase 1):
  - All fields from `_background/equations.md` Parameters table
  - Default values matching C++ reference
  - `@kwdef` for keyword construction
- [ ] `is_feasible(levers::Levers, city::CityParameters)` → Bool
- [ ] `validate_parameters(city::CityParameters)` → throws on invalid
- [ ] `Zone{T}` struct:
  - Fields: `z_low::T`, `z_high::T`, `value::T`, `zone_type::Symbol`
- [ ] Zone type constants:
  - `const ZONE_WITHDRAWN = :withdrawn`
  - `const ZONE_RESISTANT = :resistant`
  - `const ZONE_UNPROTECTED = :unprotected`
  - `const ZONE_DIKE_PROTECTED = :dike_protected`
  - `const ZONE_ABOVE_DIKE = :above_dike`

#### Wrappers (`src/wrappers.jl`)

Each wrapper extracts parameters from structs and calls corresponding Core function.

- [ ] `calculate_dike_volume(city::CityParameters, D)`:
  - Calls `Core.dike_volume(city.H_city, city.D_city, city.D_startup, city.s_dike, city.w_d, city.W_city, D)`
- [ ] `calculate_withdrawal_cost(city::CityParameters, W)`:
  - Calls `Core.withdrawal_cost(city.V_city, city.H_city, city.f_w, W)`
- [ ] `calculate_value_after_withdrawal(city::CityParameters, W)`:
  - Calls `Core.value_after_withdrawal(city.V_city, city.H_city, city.f_l, W)`
- [ ] `calculate_resistance_cost_fraction(city::CityParameters, P)`:
  - Calls `Core.resistance_cost_fraction(city.f_adj, city.f_lin, city.f_exp, city.t_exp, P)`
- [ ] `calculate_resistance_cost(city::CityParameters, levers::Levers)`:
  - Computes `V_w` and `f_cR` first
  - Calls `Core.resistance_cost(...)`
  - Warns if `R > B` (dominated strategy)
- [ ] `calculate_dike_cost(city::CityParameters, D)`:
  - Computes `V_dike` first via `calculate_dike_volume`
  - Calls `Core.dike_cost(V_dike, city.c_d)`
- [ ] `calculate_investment_cost(city::CityParameters, levers::Levers)`:
  - Returns `C_W + C_R + C_D`
- [ ] `calculate_effective_surge(h_raw, city::CityParameters)`:
  - Calls `Core.effective_surge(h_raw, city.H_seawall, city.f_runup)`
- [ ] `calculate_dike_failure_probability(h_at_dike, D, city::CityParameters)`:
  - Calls `Core.dike_failure_probability(h_at_dike, D, city.t_fail, city.p_min)`
- [ ] `calculate_city_zones(city::CityParameters, levers::Levers)` → `Vector{Zone}`:
  - Computes `V_w` via `calculate_value_after_withdrawal`
  - Calls `Core.zone_boundaries(...)` and `Core.zone_values(...)`
  - Constructs 5 `Zone` structs with appropriate `zone_type`

#### Module Updates

- [ ] Update `src/ICOW.jl`:
  - `include("types.jl")`
  - `include("wrappers.jl")`
  - Export all types and wrapper functions
- [ ] Create `test/shared/types_tests.jl`:
  - Test `Levers` construction and constraints
  - Test `CityParameters` defaults match C++ values
  - Test `Zone` struct
  - Test `is_feasible` and `validate_parameters`
- [ ] Create `test/shared/wrappers_tests.jl`:
  - Test each wrapper function
  - Verify wrapper results match direct Core calls
  - Test `calculate_city_zones` returns correct zone structure

### Validation Criteria

- [ ] All wrapper functions work with struct inputs
- [ ] `calculate_city_zones` returns 5 zones with correct boundaries
- [ ] `test/shared/` tests pass
- [ ] Package loads and exports all new symbols

---

## Phase 3: Create Stochastic Submodule

**Goal:** SimOptDecisions integration for discrete event simulation.

**Status:** Not Started

**Depends on:** Phase 2 complete

**Reference files:**

- SimOptDecisions API: `/Users/jamesdoss-gollin/Documents/dossgollin-lab/SimOptDecisions/src/`
- Current simulation logic: `src/simulation.jl` (to be adapted)
- Damage calculation: `src/Core/damage.jl`

### Tasks

#### Submodule Structure

- [ ] Create `src/Stochastic/Stochastic.jl`:
  ```julia
  module Stochastic
  using ..ICOW  # Access shared types
  using SimOptDecisions
  using Random
  # includes...
  end
  ```
- [ ] Create directory `src/Stochastic/`

#### Scenario (`src/Stochastic/scenario.jl`)

- [ ] `StochasticScenario{T} <: SimOptDecisions.AbstractScenario`:
  - `surges::Matrix{T}` — dimensions: (n_scenarios, n_years)
  - `discount_rate::T` — for NPV calculations
  - `start_year::Int` — calendar year of first simulation year
  - Constructor validates matrix dimensions
- [ ] `n_scenarios(s::StochasticScenario)` → number of scenarios (rows)
- [ ] `n_years(s::StochasticScenario)` → number of years (columns)
- [ ] `get_surge(s::StochasticScenario, year::Int, scenario_idx::Int)` → surge height for that year/scenario

#### Config (`src/Stochastic/config.jl`)

- [ ] `StochasticConfig{T} <: SimOptDecisions.AbstractConfig`:
  - `city::CityParameters{T}`
  - Forward field access: `Base.getproperty` delegates to `city`

#### State (`src/Stochastic/state.jl`)

- [ ] `StochasticState{T} <: SimOptDecisions.AbstractState`:
  - `zones::Vector{Zone{T}}` — current 5 zones
  - Or alternatively: `current_levers::Levers{T}` (simpler, derive zones when needed)
  - **Decision needed:** zones vs levers in state? (Ask user if unclear after reviewing)
- [ ] Constructor for zero-protection initial state

#### Policy (`src/Stochastic/policy.jl`)

- [ ] `StaticPolicy{T} <: SimOptDecisions.AbstractPolicy`:
  - `target_levers::Levers{T}` — levers to apply in year 1
- [ ] `SimOptDecisions.params(p::StaticPolicy)` → vector of 5 parameters
- [ ] `SimOptDecisions.param_bounds(::Type{StaticPolicy})` → bounds for optimization

#### Outcome (`src/Stochastic/outcome.jl`)

- [ ] `StochasticOutcome{T}`:
  - `total_investment::T` — discounted total investment cost
  - `total_damage::T` — discounted total damage

#### Simulation Callbacks (`src/Stochastic/simulation.jl`)

- [ ] `SimOptDecisions.initialize(config::StochasticConfig, scenario::StochasticScenario, rng)`:
  - Returns initial `StochasticState` with zero protection
- [ ] `SimOptDecisions.time_axis(config::StochasticConfig, scenario::StochasticScenario)`:
  - Returns `1:n_years(scenario)`
- [ ] `SimOptDecisions.get_action(policy::StaticPolicy, state::StochasticState, t::TimeStep, scenario)`:
  - Year 1: return `policy.target_levers`
  - Other years: return zero levers (no additional investment)
- [ ] `SimOptDecisions.run_timestep(state, action, t, config, scenario, rng)`:
  - Enforce irreversibility: `new_levers = max(state.current_levers, action)`
  - Check feasibility; return Inf costs if infeasible
  - Calculate marginal investment cost (new - old)
  - Get surge from scenario: `get_surge(scenario, t.t, scenario_idx)`
  - Calculate effective surge
  - **Sample** dike failure: `rand(rng) < p_fail`
  - Calculate damage using `Core.total_event_damage` with sampled `dike_failed`
  - Return `(new_state, step_record)`
- [ ] `SimOptDecisions.compute_outcome(records, config, scenario)`:
  - Aggregate investment and damage with discounting
  - Return `StochasticOutcome`

#### Optimization (`src/Stochastic/optimization.jl`)

- [ ] `optimize(config, scenarios, policy_type; kwargs...)`:
  - Wrapper around `SimOptDecisions.optimize`
  - Sets up objectives (minimize investment, minimize damage)

#### Tests

- [ ] Create `test/stochastic/scenario_tests.jl`:
  - Test scenario construction
  - Test `get_surge` indexing
- [ ] Create `test/stochastic/simulation_tests.jl`:
  - Test irreversibility enforcement
  - Test marginal costing (only pay for increments)
  - Test dike failure sampling produces variation
  - Test discounting
- [ ] Create `test/stochastic/optimization_tests.jl`:
  - Test `optimize` runs without error

### Validation Criteria

- [ ] Can run: `SimOptDecisions.simulate(config, scenario, policy)`
- [ ] Irreversibility enforced (levers never decrease)
- [ ] Dike failure is stochastic (different runs produce different damages)
- [ ] Discounting applied correctly
- [ ] All `test/stochastic/` tests pass

---

## Phase 4: Create EAD Submodule

**Goal:** SimOptDecisions integration for expected annual damage.

**Status:** Not Started

**Depends on:** Phase 2 complete (can be parallel with Phase 3)

**Reference files:**

- EAD calculation: `_background/equations.md` (Expected Annual Damage section)
- Current EAD logic: `src/simulation.jl` (`_ead_monte_carlo`, `_ead_quadrature`)
- Integration: uses `QuadGK` for quadrature

### Tasks

#### Submodule Structure

- [ ] Create `src/EAD/EAD.jl`:
  ```julia
  module EAD
  using ..ICOW  # Access shared types
  using SimOptDecisions
  using Distributions
  using QuadGK
  # includes...
  end
  ```
- [ ] Create directory `src/EAD/`

#### Scenario (`src/EAD/scenario.jl`)

- [ ] `EADScenario{T,D<:Distribution} <: SimOptDecisions.AbstractScenario`:
  - `distributions::Vector{D}` — surge distribution for each year
  - `discount_rate::T`
  - `start_year::Int`
  - `method::Symbol` — `:quad` or `:mc`
  - `n_samples::Int` — for MC method (default 1000)
- [ ] `n_years(s::EADScenario)` → length of distributions vector
- [ ] `get_distribution(s::EADScenario, year::Int)` → distribution for that year

#### Config (`src/EAD/config.jl`)

- [ ] `EADConfig{T} <: SimOptDecisions.AbstractConfig`:
  - `city::CityParameters{T}`
  - Forward field access to `city`

#### State (`src/EAD/state.jl`)

- [ ] `EADState{T} <: SimOptDecisions.AbstractState`:
  - `current_levers::Levers{T}` (or zones — match decision from Phase 3)
- [ ] Constructor for zero-protection initial state

#### Policy (`src/EAD/policy.jl`)

- [ ] `StaticPolicy{T} <: SimOptDecisions.AbstractPolicy`:
  - Same structure as Stochastic version
  - `target_levers::Levers{T}`
- [ ] `SimOptDecisions.params` and `param_bounds`

#### Outcome (`src/EAD/outcome.jl`)

- [ ] `EADOutcome{T}`:
  - `total_investment::T`
  - `expected_damage::T` — discounted expected annual damage

#### Simulation Callbacks (`src/EAD/simulation.jl`)

- [ ] `SimOptDecisions.initialize(config::EADConfig, scenario::EADScenario, rng)`:
  - Returns initial `EADState` with zero protection
- [ ] `SimOptDecisions.time_axis(config::EADConfig, scenario::EADScenario)`:
  - Returns `1:n_years(scenario)`
- [ ] `SimOptDecisions.get_action(policy::StaticPolicy, state::EADState, t::TimeStep, scenario)`:
  - Year 1: return target levers
  - Other years: return zero levers
- [ ] `SimOptDecisions.run_timestep(state, action, t, config, scenario, rng)`:
  - Enforce irreversibility
  - Check feasibility
  - Calculate marginal investment cost
  - Get distribution: `get_distribution(scenario, t.t)`
  - **Integrate** expected damage over distribution:
    - If `:quad`: use `QuadGK.quadgk` with `Core.expected_damage_given_surge`
    - If `:mc`: Monte Carlo sampling from distribution
  - Return `(new_state, step_record)`
- [ ] `SimOptDecisions.compute_outcome(records, config, scenario)`:
  - Aggregate with discounting
  - Return `EADOutcome`

#### Integration Helpers (`src/EAD/integration.jl`)

- [ ] `ead_quadrature(city, levers, dist; rtol=1e-6)`:
  - Handle `Dirac` distributions specially (evaluate directly)
  - Use `quadgk` for continuous distributions
- [ ] `ead_monte_carlo(city, levers, dist, rng; n_samples=1000)`:
  - Sample from distribution, compute expected damage for each
  - Average results

#### Optimization (`src/EAD/optimization.jl`)

- [ ] `optimize(config, scenarios, policy_type; kwargs...)`:
  - Wrapper around `SimOptDecisions.optimize`

#### Tests

- [ ] Create `test/ead/scenario_tests.jl`:
  - Test scenario construction with various distributions
  - Test `get_distribution`
- [ ] Create `test/ead/simulation_tests.jl`:
  - Test zero surge distribution → zero damage
  - Test Dirac distribution matches deterministic calculation
  - Test MC and quadrature agree (within tolerance)
  - Test discounting
- [ ] Create `test/ead/optimization_tests.jl`:
  - Test `optimize` runs without error

### Validation Criteria

- [ ] Can run: `SimOptDecisions.simulate(config, scenario, policy)`
- [ ] Quadrature and MC methods agree within tolerance
- [ ] Dirac distributions work (deterministic case)
- [ ] Discounting applied correctly
- [ ] All `test/ead/` tests pass

---

## Phase 5: Cleanup

**Goal:** Remove old code, finalize structure.

**Status:** Not Started

**Depends on:** Phases 3 and 4 complete

### Tasks

- [ ] Delete obsolete files:
  - [ ] `src/forcing.jl`
  - [ ] `src/scenarios.jl`
  - [ ] `src/states.jl`
  - [ ] `src/policies.jl`
  - [ ] `src/outcomes.jl`
  - [ ] `src/simulation.jl`
  - [ ] `src/optimization.jl`
  - [ ] `src/config.jl`
- [ ] Update `src/ICOW.jl`:
  - [ ] Remove includes for deleted files
  - [ ] Add `include("Stochastic/Stochastic.jl")`
  - [ ] Add `include("EAD/EAD.jl")`
  - [ ] Update exports
- [ ] Reorganize tests:
  - [ ] Move/adapt existing tests to `test/core/`, `test/shared/`, etc.
  - [ ] Delete tests for removed functionality
  - [ ] Update `test/runtests.jl` to include new test structure
- [ ] Verify package loads cleanly: `using ICOW`
- [ ] Verify both submodules accessible: `using ICOW.Stochastic`, `using ICOW.EAD`

### Validation Criteria

- [ ] No obsolete files remain
- [ ] Package loads without warnings
- [ ] All tests pass
- [ ] Both simulation modes work end-to-end

---

## Phase 6: Documentation

**Goal:** Update docs to reflect new architecture.

**Status:** Not Started

**Depends on:** Phase 5 complete

### Tasks

- [ ] Update `docs/index.qmd`:
  - [ ] New API overview
  - [ ] Stochastic vs EAD mode explanation
  - [ ] Quick start examples for both modes
- [ ] Add usage examples:
  - [ ] Stochastic simulation example
  - [ ] EAD simulation example
  - [ ] Optimization example
- [ ] Update `_background/equations.md` if needed:
  - [ ] Document any formula clarifications discovered
  - [ ] Update implementation notes
- [ ] Update `CLAUDE.md` with lessons learned from this refactor
- [ ] Clean up this ROADMAP:
  - [ ] Move completed phases to an "Archive" section
  - [ ] Update status table

### Validation Criteria

- [ ] Docs build without error
- [ ] Examples in docs are runnable
- [ ] CLAUDE.md updated with lessons learned

---

## Notes

- **Zero backwards compatibility** — delete deprecated code immediately
- **Core is math** — pure functions, individual parameters, matches equations.md
- **Submodules are independent** — can use Stochastic or EAD without the other
- **SimOptDecisions types only in submodules** — not in Core or shared types
- **Dike repair is implicit** — `f_failed = 1.5` conceptually includes repair costs
- **Ask on ambiguity** — do not guess, always ask the user
