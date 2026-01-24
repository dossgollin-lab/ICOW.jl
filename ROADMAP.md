# ICOW SimOptDecisions Integration Roadmap

## Overview

Major refactor to integrate with new SimOptDecisions API and improve code architecture.

## Phase 1: Create Core Submodule

**Goal:** Isolate pure physics code from SimOptDecisions types.
Physics functions take numeric arguments, not structs.

### Tasks

- [ ] Create `src/Core/Core.jl` submodule structure
- [ ] Move `Levers` to Core as plain struct (remove `<: AbstractAction`)
- [ ] Refactor `geometry.jl` to pure numeric functions:
  - `calculate_dike_volume(H_city, D_city, D_startup, s_dike, w_d, W_city, D)`
- [ ] Refactor `costs.jl` to pure numeric functions:
  - `calculate_withdrawal_cost(V_city, H_city, f_w, W)`
  - `calculate_value_after_withdrawal(V_city, H_city, f_l, W)`
  - `calculate_resistance_cost_fraction(f_adj, f_lin, f_exp, t_exp, P)`
  - `calculate_resistance_cost(V_w, f_cR, H_bldg, H_city, W, R, B, b_basement)`
  - `calculate_dike_cost(V_dike, c_d)`
  - `calculate_effective_surge(h_raw, H_seawall, f_runup)`
  - `calculate_dike_failure_probability(h_surge, D, t_fail, p_min)`
- [ ] Refactor `zones.jl` to pure numeric functions:
  - `calculate_zone_boundaries(H_city, W, R, B, D)` returns tuple of boundaries
  - `calculate_zone_values(V_w, H_city, W, R, B, D, r_prot, r_unprot)` returns tuple of values
- [ ] Refactor `damage.jl` to pure numeric functions:
  - `calculate_base_zone_damage(z_low, z_high, value, h_surge, b_basement, H_bldg, f_damage)`
  - `calculate_event_damage(...)` takes all needed numerics
- [ ] Create wrapper functions in Core that take `(city, levers)` and call pure functions
- [ ] Move `CityParameters` to Core as plain struct (remove `<: AbstractConfig`)
- [ ] Update C++ validation tests to use Core functions
- [ ] Verify all physics tests pass

### Validation Checkpoint

User validates Phase 1 locally before proceeding.

## Phase 2: Refactor Main Module for SimOptDecisions

**Goal:** Use new SimOptDecisions macros and callbacks.

### Tasks

- [ ] Update SimOptDecisions dependency to latest version
- [ ] Delete old simulation.jl (custom `SimOptDecisions.simulate` methods)
- [ ] Delete old forcing.jl (`AbstractSOW` types)
- [ ] Create new scenarios using `@scenariodef`:
  - `EADScenario` with `@generic forcing`, `@continuous discount_rate`
  - `StochasticScenario` with `@generic forcing`, `@discrete scenario_idx`
- [ ] Create new policies using `@policydef`:
  - `StaticPolicy` with `@continuous` fields for W, R, P, D, B
- [ ] Create `ICOWConfig` using `@configdef` that wraps `Core.CityParameters`
- [ ] Implement five callbacks in `simulation.jl`:
  - `initialize(config, scenario, rng)`
  - `time_axis(config, scenario)`
  - `get_action(policy, state, t, scenario)`
  - `run_timestep(state, action, t, config, scenario, rng)`
  - `compute_outcome(step_records, config, scenario)`
- [ ] Update `State` to use `SimOptDecisions.AbstractState`
- [ ] Create `ICOWOutcome` using `@outcomedef`
- [ ] Update optimization.jl to use new API
- [ ] Update all tests for new API

### Validation Checkpoint

User validates Phase 2 locally before proceeding.

## Phase 3: Leverage New SimOptDecisions Features

**Goal:** Use exploration, streaming, and other new features.

### Tasks

- [ ] Add `explore()` interface for policy/scenario exploration
- [ ] Add streaming output support (Zarr/CSV sinks)
- [ ] Add declarative metrics (expected value, quantiles, etc.)
- [ ] Update documentation examples to use new features
- [ ] Add executor support (sequential, threaded, distributed)

### Validation Checkpoint

User validates Phase 3 locally before proceeding.

## Phase 4: Documentation Update

**Goal:** Update all docs to reflect new architecture.

### Tasks

- [ ] Update `docs/index.qmd` with new API overview
- [ ] Update `docs/examples/getting_started.qmd`
- [ ] Update `docs/examples/ead_analysis.qmd`
- [ ] Update `docs/examples/ead_optimization.qmd`
- [ ] Update `docs/examples/stochastic_analysis.qmd`
- [ ] Update `docs/examples/stochastic_optimization.qmd`
- [ ] Update `_background/framework.md` for new architecture

## Phase 5: Comprehensive Audit

**Goal:** Remove all dead code, simplify, and clean up.

### Tasks

- [ ] Delete backward compatibility code:
  - `parameters()` function in policies.jl
  - `valid_bounds()` function
  - `:scalar` vs `:trace` mode complexity
  - All `kwargs...` passthrough
- [ ] Audit exports: remove unused, add missing
- [ ] Audit tests: remove redundant, consolidate
- [ ] Delete debug scripts in `test/validation/`
- [ ] Review and simplify objectives.jl
- [ ] Review and simplify visualization.jl
- [ ] Final test pass
- [ ] Final documentation review

## Architecture After Refactor

```
src/
├── ICOW.jl              # Main module, re-exports Core + SimOptDecisions bridge
├── Core/
│   ├── Core.jl          # Submodule: pure physics
│   ├── types.jl         # Levers, CityParameters (plain structs)
│   ├── geometry.jl      # Pure numeric functions
│   ├── costs.jl         # Pure numeric functions
│   ├── zones.jl         # Pure numeric functions
│   └── damage.jl        # Pure numeric functions
├── scenarios.jl         # @scenariodef types
├── policies.jl          # @policydef types
├── config.jl            # @configdef types
├── outcomes.jl          # @outcomedef types
├── simulation.jl        # Five SimOptDecisions callbacks
├── optimization.jl      # optimize() wrapper
├── objectives.jl        # NPV calculations
└── visualization.jl     # Plotting utilities
```

## Notes

- Zero backwards compatibility - delete deprecated code immediately
- Physics functions are pure: take numerics, return numerics
- SimOptDecisions types only in main module, not Core
- Core is validated against C++ reference implementation
