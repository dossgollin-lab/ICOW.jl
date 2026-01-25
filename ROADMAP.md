# ICOW Development Roadmap

## Status

| Phase | Status | Notes |
|-------|--------|-------|
| 1. Core Pure Functions | Complete | Types moved to src/types.jl, Core exports only functions |
| 2. Convenience Wrappers | Complete | Types done; wrappers deferred as unnecessary |
| 3. Stochastic Submodule | Not Started | |
| 4. EAD Submodule | Not Started | |
| 5. Cleanup | Not Started | Old test files need cleanup (pre-existing) |
| 6. Documentation | Not Started | |

**Current Phase:** 3 (Stochastic Submodule)

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

## SimOptDecisions API Reference

Reference: `/Users/jamesdoss-gollin/Documents/dossgollin-lab/SimOptDecisions/src/`

### Abstract Types

Users subtype these to create domain-specific implementations:

| Type | Purpose |
|------|---------|
| `AbstractConfig` | Immutable problem configuration (city parameters, constants) |
| `AbstractScenario` | Uncertainty representation (surge time series, distributions) |
| `AbstractState` | System state at any timestep (current defenses) |
| `AbstractPolicy` | Decision rule mapping (state, time, scenario) → action |
| `AbstractOutcome` | Final simulation result (investment, damage totals) |

### Required Callbacks

Five methods must be implemented for each Config/Scenario/Policy combination:

```julia
# 1. Create initial state before first timestep
SimOptDecisions.initialize(config, scenario, rng) → State

# 2. Define time points to iterate over
SimOptDecisions.time_axis(config, scenario) → 1:n_years

# 3. Map (policy, state, time, scenario) to action
SimOptDecisions.get_action(policy, state, t::TimeStep, scenario) → Action

# 4. Execute one timestep: (state, action) → (new_state, step_record)
SimOptDecisions.run_timestep(state, action, t::TimeStep, config, scenario, rng) → (State, StepRecord)

# 5. Aggregate step records into final outcome
SimOptDecisions.compute_outcome(step_records, config, scenario) → Outcome
```

### Simulation Flow

```
simulate(config, scenario, policy, rng)
  │
  ├── state = initialize(config, scenario, rng)
  │
  ├── for t in time_axis(config, scenario):
  │     action = get_action(policy, state, t, scenario)
  │     (state, record) = run_timestep(state, action, t, config, scenario, rng)
  │     push!(records, record)
  │
  └── return compute_outcome(records, config, scenario)
```

### TimeStep Helper

`TimeStep` wraps both index and value:

- `index(t)` → 1-based position
- `value(t)` → actual time (year number)
- `is_first(t)` → true if first timestep
- `discount_factor(rate, t)` → `1 / (1 + rate)^value(t)`

### Optimization API

For policy optimization:

```julia
# Policy must implement:
SimOptDecisions.params(policy) → Vector{Float64}           # Extract parameters
SimOptDecisions.param_bounds(::Type{Policy}) → Vector{Tuple{Float64,Float64}}  # Bounds

# Run optimization:
objectives = [minimize(:damage), minimize(:investment)]
result = optimize(config, scenarios, PolicyType, metric_calculator, objectives;
                  backend=MetaheuristicsBackend(algorithm=:ECA))

# Access Pareto front:
for (params, obj_values) in pareto_front(result)
    # ...
end
```

### Metric Computation

Declarative metrics for outcome aggregation:

```julia
metrics = [
    ExpectedValue(:mean_cost, :cost),
    Variance(:var_damage, :damage),
    Quantile(:q95_loss, :loss, 0.95),
]
result = compute_metrics(metrics, outcomes)  # → NamedTuple
```

### Key Design Patterns

1. **Type stability**: Use parametric structs `struct Policy{T<:Real}` for specialization
2. **Zero allocations**: Use `NoRecorder()` in optimization (default)
3. **RNG control**: All callbacks receive `AbstractRNG` for reproducibility
4. **Step records**: Return NamedTuples from `run_timestep` for type stability

---

## Overview

Reorganize ICOW into a clean architecture:

1. **Core** = pure functions only (no structs), syntax matches equations.md
2. **Main ICOW module** = shared user-facing types (FloodDefenses, CityParameters, Zone)
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

### SimOptDecisions Macros

Use SimOptDecisions definition macros throughout for full framework integration:

| Type | Macro | Notes |
|------|-------|-------|
| Config | `@configdef` | Wraps CityParameters fields with `@continuous` |
| Scenario | `@scenariodef` | Uses `@timeseries` for surges, `@continuous` for discount_rate |
| State | Manual struct | Must be mutable; convert FloodDefenses to/from 5 scalars |
| Policy | `@policydef` | Uses reparameterized bounds (see below) |
| Outcome | `@outcomedef` | `@continuous` for investment, damage |

### Policy Reparameterization

**Problem:** FloodDefenses constraints depend on `H_city` (config-dependent), but `@policydef` requires static bounds.

**Actual constraints** (from `FloodDefenses` constructor and `is_feasible`):

1. `W ≥ 0`
2. `B ≥ 0`
3. `D ≥ 0`
4. `R ≥ 0`
5. `W + B + D ≤ H_city`
6. `0 ≤ P < 1`

**Note:** There is NO constraint `B ≥ W`. B is a relative height (dike base above W), so `B ≥ 0` is sufficient.

**Solution:** Stick-breaking reparameterization with fractions:

```julia
@policydef StaticPolicy begin
    @continuous a_frac 0.0 1.0    # total height budget as fraction of H_city
    @continuous w_frac 0.0 1.0    # W's share of budget
    @continuous b_frac 0.0 1.0    # B's share of remaining (A - W)
    @continuous r_frac 0.0 1.0    # R as fraction of H_city (independent)
    @continuous P 0.0 0.99        # resistance fraction
end
```

**Conversion to FloodDefenses (via constructor):**

```julia
# Extend FloodDefenses with policy conversion constructors
function FloodDefenses(policy::StaticPolicy, city::CityParameters)
    H_city = city.H_city
    A = value(policy.a_frac) * H_city    # total height budget
    W = value(policy.w_frac) * A          # withdrawal
    remaining = A - W                      # remaining for B + D
    B = value(policy.b_frac) * remaining  # dike base
    D = remaining - B                      # dike height = (1 - b_frac) * remaining
    R = value(policy.r_frac) * H_city     # resistance (independent)
    P = value(policy.P)
    return FloodDefenses(W, R, P, D, B)
end

FloodDefenses(policy::StaticPolicy, config::StochasticConfig) = FloodDefenses(policy, config.city)
```

**Why it works:**

| Constraint | Guaranteed by |
|------------|---------------|
| `W ≥ 0` | `w_frac ≥ 0`, `a_frac ≥ 0` |
| `B ≥ 0` | `b_frac ≥ 0`, `remaining ≥ 0` |
| `D ≥ 0` | `D = (1-b_frac) * remaining`, both terms ≥ 0 |
| `W + B + D ≤ H` | `W + B + D = W + remaining = A = a_frac * H ≤ H` |
| `R ≥ 0` | `r_frac ≥ 0` |
| `P < 1` | `P ≤ 0.99` |

**Edge cases:**

| Parameters | Result | Valid? |
|------------|--------|--------|
| `a_frac=0` | W=B=D=0 (no protection) | ✓ |
| `a_frac=1, w_frac=0` | W=0, B+D=H | ✓ |
| `a_frac=1, w_frac=1` | W=H, B=D=0 | ✓ |
| `a_frac=1, w_frac=0.5, b_frac=0.5` | W=H/2, B=H/4, D=H/4 | ✓ |

**Optimization note:** `R > B` is allowed but economically wasteful (resistance is capped at `min(R, B)` for zone calculations). The optimizer will naturally discover this.

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
├── types.jl             # FloodDefenses, CityParameters, Zone (user-facing structs)
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
- Types: `src/types.jl` (FloodDefenses, CityParameters)

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

- [x] Move `FloodDefenses{T}` struct from `src/Core/types.jl` to `src/types.jl`
  - Copy struct definition and constructor
  - Copy `is_feasible` function
  - Copy `Base.max` method for irreversibility
- [x] Move `CityParameters{T}` struct from `src/Core/types.jl` to `src/types.jl`
  - Copy struct definition with all fields and defaults
  - Copy `validate_parameters` function
- [x] Delete `src/Core/types.jl`
- [x] Update `src/Core/Core.jl`:
  - Remove `include("types.jl")`
  - Remove type exports (`FloodDefenses`, `CityParameters`, `validate_parameters`, `is_feasible`)
  - Keep only function exports
- [x] Update `src/ICOW.jl` to include new `src/types.jl`
- [x] Verify Core functions still work (they take individual params, not structs)
- [x] Run C++ validation to confirm no regression

### Validation Criteria

- [x] `Core` module exports ONLY functions, no types
- [x] `src/types.jl` contains `FloodDefenses` and `CityParameters`
- [x] C++ validation passes
- [x] Package loads without error: `using ICOW`

---

## Phase 2: Convenience Wrappers (Optional)

**Goal:** Add convenience wrappers if needed for user-facing API.

**Status:** Mostly Complete (types done, wrappers deferred)

**Depends on:** Phase 1 complete

### Completed Tasks

Types are already in `src/types.jl`:

- [x] `FloodDefenses{T}` struct with constraint validation and `Base.max`
- [x] `CityParameters{T}` struct with `@kwdef` and defaults
- [x] `is_feasible(levers::FloodDefenses, city::CityParameters)` → Bool
- [x] `validate_parameters(city::CityParameters)` → throws on invalid
- [x] Tests in `test/types_tests.jl`

### Deferred Tasks

The following were deemed unnecessary complexity. The simulation code in `src/simulation.jl` calls Core functions directly with field extraction, which is simple and clear.

- [~] `Zone{T}` struct — Core returns tuples, no need for struct wrapper
- [~] Wrappers (`src/wrappers.jl`) — Direct Core calls in simulation.jl are cleaner
- [~] `test/shared/wrappers_tests.jl` — Not needed without wrappers

### Validation Criteria

- [x] Types work with SimOptDecisions integration
- [x] `test/types_tests.jl` passes
- [x] Package loads and exports types

---

## Phase 3: Create Stochastic Submodule

**Goal:** SimOptDecisions integration for discrete event simulation using definition macros.

**Status:** Not Started

**Depends on:** Phase 2 complete

**Reference files:**

- SimOptDecisions API: See "SimOptDecisions API Reference" section above
- Current simulation logic: `src/simulation.jl` (to be adapted)
- Policy reparameterization: See "Policy Reparameterization" section above

### File Structure

```
src/Stochastic/
├── Stochastic.jl      # Module definition, includes, exports
├── types.jl           # Config, Scenario, State, Policy, Outcome
└── simulation.jl      # 5 SimOptDecisions callbacks + helpers
```

### Tasks

#### Submodule Structure

- [ ] Create directory `src/Stochastic/`
- [ ] Create `src/Stochastic/Stochastic.jl`:
  ```julia
  module Stochastic
  using ..ICOW: FloodDefenses, CityParameters, is_feasible, Core
  using SimOptDecisions
  using Random
  include("types.jl")
  include("simulation.jl")
  export StochasticConfig, StochasticScenario, StochasticState
  export StaticPolicy, StochasticOutcome
  end
  ```
- [ ] Update `src/ICOW.jl` to include submodule

#### Types (`src/Stochastic/types.jl`)

- [ ] `StochasticConfig` using `@configdef`:
  ```julia
  @configdef StochasticConfig begin
      @generic city CityParameters
  end
  ```
- [ ] `StochasticScenario` using `@scenariodef`:
  ```julia
  @scenariodef StochasticScenario begin
      @timeseries surges        # Vector{T} of surge heights per year
      @continuous discount_rate # for NPV calculations
  end
  ```
- [ ] `StochasticState` (mutable, manual struct):
  ```julia
  mutable struct StochasticState{T<:AbstractFloat} <: AbstractState
      W::T; R::T; P::T; D::T; B::T
  end
  ```
  - [ ] `to_flood_defenses(state)` → FloodDefenses
  - [ ] `update_state!(state, fd)` → mutate state from FloodDefenses
- [ ] `StaticPolicy` using `@policydef` with reparameterized fractions:
  ```julia
  @policydef StaticPolicy begin
      @continuous a_frac 0.0 1.0  # total height budget fraction
      @continuous w_frac 0.0 1.0  # W's share of budget
      @continuous b_frac 0.0 1.0  # B's share of remaining
      @continuous r_frac 0.0 1.0  # R as fraction of H_city
      @continuous P 0.0 0.99      # resistance fraction
  end
  ```
  - [ ] `FloodDefenses(policy, city)` and `FloodDefenses(policy, config)` constructors
- [ ] `StochasticOutcome` using `@outcomedef`:
  ```julia
  @outcomedef StochasticOutcome begin
      @continuous investment
      @continuous damage
  end
  ```

#### Simulation Callbacks (`src/Stochastic/simulation.jl`)

- [ ] `SimOptDecisions.initialize(config, scenario, rng)`:
  - Returns `StochasticState` with zero protection
- [ ] `SimOptDecisions.time_axis(config, scenario)`:
  - Returns `1:length(value(scenario.surges))`
- [ ] `SimOptDecisions.get_action(policy, state, t, scenario)`:
  - Year 1: return policy (fractions)
  - Other years: return zero policy
  - **Note:** Returns policy object, not FloodDefenses (conversion in run_timestep)
- [ ] `SimOptDecisions.run_timestep(state, action, t, config, scenario, rng)`:
  - Convert action to FloodDefenses: `fd = FloodDefenses(action, config)`
  - Enforce irreversibility: `new_defenses = max(current, action_defenses)`
  - Check feasibility; return Inf costs if infeasible
  - Calculate marginal investment cost
  - Sample dike failure: `rand(rng) < p_fail`
  - Calculate damage using `Core.total_event_damage`
  - Return `(state, step_record)` where step_record includes defenses for tracing
- [ ] `SimOptDecisions.compute_outcome(records, config, scenario)`:
  - Aggregate investment and damage with discounting
  - Return `StochasticOutcome`

#### Helper Functions

- [ ] Copy `_investment_cost(city, fd)` from existing `src/simulation.jl`
- [ ] Copy `_stochastic_damage(city, fd, h_raw, rng)` from existing `src/simulation.jl`

#### Tests

- [ ] Create `test/stochastic/` directory
- [ ] Create `test/stochastic/types_tests.jl`:
  - Policy reparameterization produces valid FloodDefenses
  - Edge cases (a_frac=0, a_frac=1, w_frac=1, etc.)
  - State initialization and conversion
- [ ] Create `test/stochastic/simulation_tests.jl`:
  - Full simulation runs without error
  - Irreversibility enforced
  - Dike failure is stochastic (different seeds → different results)
  - Discounting applied correctly
  - Step records include defense values
- [ ] Update `test/runtests.jl` to include stochastic tests

### Design Decisions (Resolved)

#### FloodDefenses Constructors from Policy

Add convenience constructors to convert reparameterized policy to FloodDefenses:

```julia
# In src/Stochastic/types.jl - extend FloodDefenses with policy conversion
function FloodDefenses(policy::StaticPolicy, city::CityParameters)
    H_city = city.H_city
    A = value(policy.a_frac) * H_city
    W = value(policy.w_frac) * A
    remaining = A - W
    B = value(policy.b_frac) * remaining
    D = remaining - B
    R = value(policy.r_frac) * H_city
    P = value(policy.P)
    return FloodDefenses(W, R, P, D, B)
end

# Convenience: also accept config directly
FloodDefenses(policy::StaticPolicy, config::StochasticConfig) = FloodDefenses(policy, config.city)
```

This encapsulates the reparameterization logic and makes `run_timestep` cleaner:
```julia
fd = FloodDefenses(action, config)  # instead of to_defenses(action, config.city.H_city)
```

#### Action Type Flow

- `get_action` returns policy object (fractions with [0,1] bounds)
- `run_timestep` converts fractions to FloodDefenses using `config.city.H_city`
- Rationale: `get_action` doesn't receive config, but `run_timestep` does

#### Step Record Contents

Step records include actual FloodDefenses for tracing:
```julia
(investment=T, damage=T, W=T, R=T, P=T, D=T, B=T)
```

### Validation Criteria

- [ ] Package loads: `using ICOW; using ICOW.Stochastic`
- [ ] Basic simulation runs:
  ```julia
  config = StochasticConfig(city=CityParameters())
  scenario = StochasticScenario(surges=[1.0, 2.0, 1.5], discount_rate=0.03)
  policy = StaticPolicy(a_frac=0.5, w_frac=0.1, b_frac=0.3, r_frac=0.2, P=0.5)
  outcome = simulate(config, scenario, policy)
  ```
- [ ] Irreversibility enforced (defenses never decrease)
- [ ] Dike failure is stochastic (different RNG seeds → different damages)
- [ ] Discounting applied correctly
- [ ] All `test/stochastic/` tests pass
- [ ] C++ validation still passes (Core unchanged)

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
  - `current_levers::FloodDefenses{T}` (or zones — match decision from Phase 3)
- [ ] Constructor for zero-protection initial state

#### Policy (`src/EAD/policy.jl`)

- [ ] `StaticPolicy{T} <: SimOptDecisions.AbstractPolicy`:
  - Same structure as Stochastic version
  - `target_levers::FloodDefenses{T}`
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
