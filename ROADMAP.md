# ICOW SimOptDecisions Integration Roadmap

## Overview

Major refactor to integrate with new SimOptDecisions API and improve code architecture.

## Phase 1: Create Core Submodule

**Goal:** Isolate pure physics code from SimOptDecisions types.
Physics functions take numeric arguments, not structs.

### Tasks

- [x] Create `src/Core/Core.jl` submodule structure
- [x] Move `Levers` to Core as plain struct (remove `<: AbstractAction`)
- [x] Move `CityParameters` to Core as plain struct (remove `<: AbstractConfig`)
- [x] Refactor `geometry.jl` to pure numeric function: `dike_volume(...)`
- [x] Refactor `costs.jl` to pure numeric functions (all use parametric typing)
- [x] Refactor `zones.jl` to pure numeric functions: `zone_boundaries`, `zone_values`
- [x] Refactor `damage.jl` to pure numeric functions: `base_zone_damage`, `zone_damage`, `total_event_damage`, `expected_damage_given_surge`
- [ ] Verify all existing tests still pass (old src/*.jl files remain for now)

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
