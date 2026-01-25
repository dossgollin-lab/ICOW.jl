# ICOW Development Roadmap

## Status

| Phase | Status | Notes |
|-------|--------|-------|
| 1. Core Pure Functions | Complete | Types moved to src/types.jl, Core exports only functions |
| 2. Convenience Wrappers | Complete | Types done; wrappers deferred as unnecessary |
| 3. Stochastic Submodule | Complete | SimOptDecisions integration with reparameterized policy |
| 4. EAD Submodule | Complete | Typed integrators (Quadrature/MC), independent from Stochastic |
| 5. Cleanup | Complete | Deprecated tests deleted, C++ validation integrated into test suite |
| 6. Documentation | Complete | New sidebar structure with 10 .qmd pages |

**Current Phase:** 6 (Documentation) -- files written, pending quarto render verification

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

1. **Constraint consistency:** When Core functions have preconditions (like `W < H_city` to avoid division by zero), the `is_feasible` check must enforce the same constraint. Audit both together.

2. **Type stability in conditionals:** When a function returns different values based on a runtime condition, ensure both branches return the same concrete type. Extract type parameters from the input that determines the output type.

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

**Goal:** SimOptDecisions integration for discrete event simulation.
Replace existing simulation code with a clean Stochastic submodule.

**Status:** Complete

**Depends on:** Phase 2 complete

**Reference files:**

- SimOptDecisions API: See "SimOptDecisions API Reference" section above
- SimOptDecisions macros: `/Users/jamesdoss-gollin/Documents/dossgollin-lab/SimOptDecisions/src/macros.jl`
- Policy reparameterization: See "Policy Reparameterization" section above
- Current simulation logic: `src/simulation.jl` (to be deleted and replaced)

### Key Design Decisions (Resolved)

These decisions were made during planning discussion:

1. **Flatten city parameters into StochasticConfig**: No intermediate `CityParameters` struct.
   Direct access via `config.H_city`. Use `Base.@kwdef` for defaults.

2. **Delete CityParameters entirely**: Remove from `src/types.jl`. Keep only `FloodDefenses`.

3. **Delete existing types from ICOW.jl**: Remove `Config`, `Scenario`, `State`, `StaticPolicy`, `StepRecord`, `Outcome` and delete `src/simulation.jl`.

4. **Type definitions**:
   - `StochasticConfig`: Plain `@kwdef struct <: AbstractConfig` (not explored/optimized)
   - `StochasticScenario`: Use `@scenariodef` with `@timeseries` and `@continuous`
   - `StochasticState`: Plain mutable struct holding `FloodDefenses{T}`
   - `StaticPolicy`: Use `@policydef` with reparameterized fractions
   - `StochasticOutcome`: Use `@outcomedef` with `@continuous`

5. **Step records**: Use NamedTuple for type stability:
   ```julia
   (investment=T, damage=T, W=T, R=T, P=T, D=T, B=T)
   ```

6. **No backwards compatibility**: Delete old code, don't maintain parallel implementations.

### File Structure

```
src/
├── ICOW.jl              # Simplified: just FloodDefenses + Core + Stochastic submodule
├── types.jl             # FloodDefenses only (CityParameters deleted)
├── Core/                # Unchanged
└── Stochastic/
    ├── Stochastic.jl    # Module definition, includes, exports
    ├── types.jl         # Config, Scenario, State, Policy, Outcome
    └── simulation.jl    # 5 SimOptDecisions callbacks + helpers
```

### Tasks

#### Cleanup Old Code

- [x] Delete `CityParameters` from `src/types.jl` (keep `FloodDefenses`, `is_feasible`, `validate_parameters` adapted for config)
- [x] Delete from `src/ICOW.jl`: `Config`, `Scenario`, `State`, `StaticPolicy`, `StepRecord`, `Outcome` structs
- [x] Delete `src/simulation.jl`
- [x] Update exports in `src/ICOW.jl`

#### Submodule Structure

- [x] Create directory `src/Stochastic/`
- [x] Create `src/Stochastic/Stochastic.jl`
- [x] Update `src/ICOW.jl` to include and re-export Stochastic submodule

#### Types (`src/Stochastic/types.jl`)

- [x] `StochasticConfig` - plain struct with flattened city parameters (28 fields)
- [x] `validate_config(config::StochasticConfig)` - validation function
- [x] `is_feasible(fd::FloodDefenses, config::StochasticConfig)` - feasibility check
- [x] `StochasticScenario` using `@scenariodef` with `@timeseries surges` and `@continuous discount_rate`
- [x] `StochasticState` - mutable struct holding `FloodDefenses{T}`
- [x] `StaticPolicy` using `@policydef` with reparameterized fractions (a_frac, w_frac, b_frac, r_frac, P)
- [x] `FloodDefenses(policy::StaticPolicy, config::StochasticConfig)` constructor
- [x] `StochasticOutcome` using `@outcomedef` with `@continuous investment, damage`
- [x] `total_cost(outcome)` helper function

#### Simulation Callbacks (`src/Stochastic/simulation.jl`)

- [x] `SimOptDecisions.initialize` - returns zero-protection state
- [x] `SimOptDecisions.time_axis` - returns `1:length(surges)`
- [x] `SimOptDecisions.get_action` - returns policy in year 1, zero policy otherwise
- [x] `SimOptDecisions.run_timestep` - converts policy to FloodDefenses, enforces irreversibility, computes costs/damage
- [x] `SimOptDecisions.compute_outcome` - aggregates with discounting

#### Helper Functions

- [x] `_investment_cost(config::StochasticConfig, fd::FloodDefenses)` - adapted from existing
- [x] `_stochastic_damage(config::StochasticConfig, fd::FloodDefenses, h_raw, rng)` - adapted from existing

#### Tests

- [x] Update `test/types_tests.jl`: remove CityParameters tests, keep FloodDefenses tests
- [x] Create `test/stochastic/` directory
- [x] Create `test/stochastic/types_tests.jl` (config, validation, policy reparameterization, edge cases)
- [x] Create `test/stochastic/simulation_tests.jl` (simulation runs, determinism, discounting)
- [x] Update `test/runtests.jl` to use new test structure
- [x] Delete `test/simulation_integration_tests.jl` (replaced by stochastic tests)

### Resolved Issue: get_action Needs Config

**Solution implemented:** Option 3 - `get_action` returns `StaticPolicy`, conversion to `FloodDefenses` happens in `run_timestep` which has access to config.

### Validation Criteria

- [x] Package loads: `using ICOW; using ICOW.Stochastic`
- [x] Basic simulation runs
- [x] Irreversibility enforced (defenses never decrease)
- [x] Dike failure is stochastic (different RNG seeds → different damages)
- [x] Discounting applied correctly
- [x] All tests pass (83 tests)
- [x] C++ validation still passes (Core unchanged)

### Post-Implementation Audit (Complete)

Comprehensive audit identified and fixed:

1. **`is_feasible` constraint mismatch (critical):** Changed `W <= H_city` to `W < H_city` to match `Core.withdrawal_cost` which requires strict inequality to avoid division by zero.

2. **Type instability in `get_action`:** Changed to extract type parameter from policy (`Tp`) instead of state (`T`), ensuring both branches return same type.

3. **Stochastic variation test:** Added test verifying different RNG seeds produce different damages (uses moderate surges near dike height for intermediate failure probability).

4. **Discount factor documentation:** Added comment explaining end-of-year discounting convention.

5. **SimOptDecisions integration:** Added `SimOptDecisions.validate_config` hook and re-exported `simulate` for convenience.

---

## Phase 4: Create EAD Submodule

**Goal:** SimOptDecisions integration for expected annual damage.

**Status:** Complete

**Depends on:** Phase 2 complete (can be parallel with Phase 3)

### Design Decisions

1. **Integration method as struct**: Instead of `method::Symbol` in scenario, use typed integrators:
   - `QuadratureIntegrator{T}` with `rtol` parameter
   - `MonteCarloIntegrator` with `n_samples` parameter
   - Enables dispatch and type-safe configuration

2. **Config duplication**: `EADConfig` duplicates the 28 fields from `StochasticConfig` for submodule independence. This allows future divergence (e.g., different MC methods).

3. **Simple file structure**: Following Stochastic pattern with `types.jl` + `simulation.jl` only.

### File Structure

```
src/EAD/
├── EAD.jl          # Module definition, includes, exports
├── types.jl        # IntegrationMethod, EADConfig, EADScenario, EADState, StaticPolicy, EADOutcome
└── simulation.jl   # 5 SimOptDecisions callbacks + integration helpers
```

### Completed Tasks

#### Submodule Structure

- [x] Create `src/EAD/EAD.jl` module
- [x] Create directory `src/EAD/`
- [x] Update `src/ICOW.jl` to include and export EAD submodule

#### Types (`src/EAD/types.jl`)

- [x] `IntegrationMethod` abstract type
- [x] `QuadratureIntegrator{T}` with `rtol::T = 1e-6`
- [x] `MonteCarloIntegrator` with `n_samples::Int = 1000`
- [x] `EADConfig{T}` - 28 city parameters (duplicated from StochasticConfig)
- [x] `validate_config(config::EADConfig)` - validation function
- [x] `is_feasible(fd::FloodDefenses, config::EADConfig)` - feasibility check
- [x] `EADScenario{T, D, M}` - distributions + discount_rate + integrator
- [x] `EADState{T}` - mutable struct holding `FloodDefenses{T}`
- [x] `StaticPolicy` using `@policydef` (same reparameterization as Stochastic)
- [x] `FloodDefenses(policy::StaticPolicy, config::EADConfig)` constructor
- [x] `EADOutcome` using `@outcomedef` with investment + expected_damage
- [x] `total_cost(outcome)` helper function

#### Simulation Callbacks (`src/EAD/simulation.jl`)

- [x] `SimOptDecisions.initialize` - returns zero-protection state
- [x] `SimOptDecisions.time_axis` - returns `1:length(distributions)`
- [x] `SimOptDecisions.get_action` - returns policy in year 1, zero policy otherwise
- [x] `SimOptDecisions.run_timestep` - computes investment + integrated expected damage
- [x] `SimOptDecisions.compute_outcome` - aggregates with discounting

#### Integration Helpers

- [x] `_investment_cost(config::EADConfig, fd::FloodDefenses)` - investment calculation
- [x] `_expected_damage_for_surge(config, fd, h_raw)` - damage for single surge
- [x] `_integrate_expected_damage(::QuadratureIntegrator, ...)` - quadrature integration
- [x] `_integrate_expected_damage(::MonteCarloIntegrator, ...)` - MC integration
- [x] Dirac distribution handling (point mass evaluation)

#### Tests

- [x] Create `test/ead/types_tests.jl` - integrators, config, scenario, policy, state
- [x] Create `test/ead/simulation_tests.jl`:
  - [x] Simulation runs with quadrature and Monte Carlo
  - [x] Zero policy produces zero investment
  - [x] Quadrature is deterministic (RNG-independent)
  - [x] Monte Carlo varies with RNG but converges
  - [x] Quadrature and MC agree within tolerance
  - [x] Discounting applied correctly
  - [x] Dirac distribution matches deterministic calculation
  - [x] Zero surge produces zero damage
- [x] Update `test/runtests.jl` to include EAD tests

### Validation Criteria

- [x] Can run: `SimOptDecisions.simulate(config, scenario, policy, rng)`
- [x] Quadrature and MC methods agree within tolerance (5%)
- [x] Dirac distributions work (deterministic case)
- [x] Discounting applied correctly
- [x] All `test/ead/` tests pass (169 total tests)

---

## Phase 5: Cleanup

**Goal:** Remove old code, finalize structure.

**Status:** Complete

**Depends on:** Phases 3 and 4 complete

### Tasks

#### Source cleanup

Obsolete source files (`src/forcing.jl`, `src/scenarios.jl`, `src/states.jl`, `src/policies.jl`, `src/outcomes.jl`, `src/simulation.jl`, `src/optimization.jl`, `src/config.jl`) were already deleted during earlier phases.
`src/ICOW.jl` already includes Stochastic and EAD submodules with correct exports.

- [x] Verify no obsolete source files remain
- [x] Verify `src/ICOW.jl` is clean (includes types, Core, Stochastic, EAD only)

#### Test cleanup

- [x] Delete `test/_deprecated/` folder (11 old test files)
- [x] Delete superfluous validation scripts (`debug_zone_damage.jl`, `validate_mode_convergence.jl`, `benchmark_ead_methods.jl`)
- [x] Convert C++ validation into proper tests:
  - [x] Commit C++ reference output files (`test/validation/cpp_reference/outputs/`)
  - [x] Create `test/core/cpp_validation_tests.jl` (parses committed outputs, validates Core functions)
  - [x] Remove old standalone `validate_cpp_outputs.jl`
- [x] Update `test/runtests.jl` to include Core validation tests
- [x] All 199 tests pass

### Validation Criteria

- [x] No obsolete files remain
- [x] Package loads without warnings
- [x] All tests pass (199 total)
- [x] Both simulation modes work end-to-end

---

## Phase 6: Documentation

**Goal:** Rewrite docs with new sidebar structure, updated API references, and executable examples.

**Status:** Complete

**Depends on:** Phase 5 complete

### Tasks

- [x] Update `CLAUDE.md` with documentation engine rule
- [x] Update `docs/_quarto.yml` sidebar structure
- [x] Rewrite `docs/index.qmd` with current API
- [x] Create `docs/core/equations.qmd` (public-facing equation reference)
- [x] Create `docs/core/architecture.qmd` (module hierarchy, types, reparameterization)
- [x] Create `docs/ead/model.qmd` (EAD conceptual overview)
- [x] Create `docs/ead/details.qmd` (EAD usage with executable examples)
- [x] Create `docs/stochastic/model.qmd` (Stochastic conceptual overview)
- [x] Create `docs/stochastic/details.qmd` (Stochastic usage with executable examples)
- [x] Create `docs/api/core.qmd` (Core API reference with docstrings)
- [x] Create `docs/api/ead.qmd` (EAD API reference)
- [x] Create `docs/api/stochastic.qmd` (Stochastic API reference)
- [x] Update ROADMAP.md
- [x] Delete stale `docs/examples/` directory

### Validation Criteria

- [ ] `quarto render` builds without errors
- [ ] All executable code blocks run successfully
- [ ] Sidebar navigation works correctly
- [x] CLAUDE.md updated with documentation conventions

---

## Notes

- **Zero backwards compatibility** — delete deprecated code immediately
- **Core is math** — pure functions, individual parameters, matches equations.md
- **Submodules are independent** — can use Stochastic or EAD without the other
- **SimOptDecisions types only in submodules** — not in Core or shared types
- **Dike repair is implicit** — `f_failed = 1.5` conceptually includes repair costs
- **Ask on ambiguity** — do not guess, always ask the user
