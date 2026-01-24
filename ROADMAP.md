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
- [x] Rewrite C++ validation to test Core directly
- [x] User validates Phase 1 locally (219 pass, 1 broken)

## Phase 2: Refactor Main Module for SimOptDecisions

**Goal:** Use SimOptDecisions five-callback model.

### Tasks

- [x] Create new scenario types:
  - `EADScenario <: AbstractScenario`
  - `StochasticScenario <: AbstractScenario`
- [x] Update `StaticPolicy` to use `Core.Levers`
- [x] Create `ICOWConfig` wrapping `Core.CityParameters`
- [x] Create `ICOWState <: AbstractState`
- [x] Create `ICOWOutcome <: AbstractOutcome`
- [x] Implement five callbacks in `simulation.jl`:
  - `initialize(config, scenario, rng)`
  - `time_axis(config, scenario)`
  - `get_action(policy, state, t, scenario)`
  - `run_timestep(state, action, t, config, scenario, rng)`
  - `compute_outcome(step_records, config, scenario)`
- [x] Update optimization.jl to use new Scenario types
- [x] Delete redundant files:
  - `types.jl`, `parameters.jl` (Core provides these)
  - `geometry.jl`, `costs.jl`, `zones.jl`, `damage.jl` (simulation.jl uses Core directly)
  - `objectives.jl`, `visualization.jl` (not needed)
- [ ] Update tests for new API (user must run tests)

### Validation Checkpoint

User validates Phase 2 locally before proceeding.

## Phase 3: Leverage New SimOptDecisions Features

**Goal:** Use exploration, streaming, and other new features.

### Tasks

- [ ] Add `explore()` interface for policy/scenario exploration
- [ ] Add streaming output support (Zarr/CSV sinks)
- [ ] Add declarative metrics (expected value, quantiles, etc.)
- [ ] Add executor support (sequential, threaded, distributed)

## Phase 4: Documentation Update

**Goal:** Update all docs to reflect new architecture.

### Tasks

- [ ] Update `docs/index.qmd` with new API overview
- [ ] Update examples in `docs/examples/`
- [ ] Update `_background/framework.md`

## Architecture After Refactor

```
src/
├── ICOW.jl           # Main module
├── Core/
│   ├── Core.jl       # Submodule: pure physics
│   ├── types.jl      # Levers, CityParameters (plain structs)
│   ├── geometry.jl   # dike_volume
│   ├── costs.jl      # withdrawal_cost, resistance_cost, dike_cost, etc.
│   ├── zones.jl      # zone_boundaries, zone_values
│   └── damage.jl     # base_zone_damage, zone_damage, total_event_damage, expected_damage_given_surge
├── config.jl         # ICOWConfig wrapper
├── forcing.jl        # StochasticForcing, DistributionalForcing
├── scenarios.jl      # EADScenario, StochasticScenario
├── states.jl         # ICOWState
├── policies.jl       # StaticPolicy
├── outcomes.jl       # ICOWOutcome
├── simulation.jl     # Five SimOptDecisions callbacks
└── optimization.jl   # optimize() wrapper
```

## Notes

- Zero backwards compatibility - delete deprecated code immediately
- Physics functions are pure: take numerics, return numerics
- SimOptDecisions types only in main module, not Core
- Core is validated against C++ reference implementation
