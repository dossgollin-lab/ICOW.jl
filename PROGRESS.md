# ICOW.jl Implementation Progress

Last updated: 2025-12-05 (Phase 0 completed)

## Current Phase

Working on: **Phase 1a: Equation Extraction - AWAITING REVIEW**

## Completed

- [x] Create CLAUDE.md with development guidelines
- [x] Create PROGRESS.md for tracking progress
- [x] Create docs/ directory
- [x] Initialize Julia package structure (Project.toml, src/, test/)

## Phase 0: Parameters & Validation

- [x] Create `src/parameters.jl` with `CityParameters`
- [x] Create `src/types.jl` with `Levers` and constraints
- [x] Create `docs/parameters.md`
- [x] Write unit tests for parameter validation
- [x] Write unit tests for lever constraints

## Phase 1: Equation Extraction (REQUIRES USER REVIEW)

- [ ] Extract ALL equations (Equations 1-9) from Ceres et al. (2019) to `docs/equations.md`
- [ ] Use LaTeX math syntax for all equations
- [ ] Include equation numbers and page references
- [ ] Define all symbols in each equation with units
- [ ] Get user approval before proceeding to implementation

## Phase 2: Geometry Implementation

- [ ] Implement `calculate_dike_volume()` in `src/geometry.jl`
- [ ] Write unit tests for volume calculation
- [ ] Validate against hand calculations

## Phase 3: Core Physics Implementation

- [ ] Implement cost functions in `src/costs.jl`
- [ ] Implement damage functions in `src/damage.jl`
- [ ] Write unit tests for costs
- [ ] Write unit tests for damage

## Phase 4: Zones Implementation

- [ ] Create `docs/zones.md` from Figure 3
- [ ] Implement `calculate_city_zones()` in `src/zones.jl`
- [ ] Implement zone-based damage in `src/damage.jl`
- [ ] Write unit tests for zone calculation
- [ ] Write unit tests for zone damage

## Phase 5: Simulation

- [ ] Implement `SimulationState` in `src/simulation.jl`
- [ ] Implement `simulate()` with scalar mode
- [ ] Implement `simulate()` with trace mode
- [ ] Implement `simulate_ensemble()`
- [ ] Write simulation tests
- [ ] Test irreversibility enforcement

## Phase 6: Policies

- [ ] Implement `AbstractPolicy` interface
- [ ] Implement `StaticPolicy`
- [ ] Implement `ThresholdPolicy`
- [ ] Write policy execution tests

## Phase 7: Optimization

- [ ] Implement `create_objective_function()`
- [ ] Implement `optimize_portfolio()`
- [ ] Implement `optimize_single_lever()`
- [ ] Write van Dantzig regression test
- [ ] Write Pareto front tests

## Phase 8: Analysis

- [ ] Implement surge generation in `src/surges.jl`
- [ ] Implement `run_forward_mode()`
- [ ] Implement `summarize_results()`
- [ ] Implement `calculate_robustness_metrics()`
- [ ] Write forward mode tests

## Documentation & Release

- [ ] Complete all `docs/*.md` files
- [ ] Write `README.md` with examples
- [ ] Add GPLv3 `LICENSE` file
- [ ] Create example notebooks
- [ ] Run full test suite
- [ ] Profile performance
- [ ] Tag v0.1.0 release

## Notes & Issues

### Session Notes

**2025-12-05 - Phase 0 Completed:**

- Implemented CityParameters struct with all exogenous parameters from Table C.3
- Implemented Levers struct with physical constraint validation
- Created comprehensive docs/parameters.md documenting all parameters
- Wrote 97 unit tests covering parameter validation and lever constraints
- All tests passing successfully
- Key design decisions:
  - Used Base.@kwdef for CityParameters to enable keyword construction
  - Implemented strict validation in Levers constructor with optional bypass
  - Added Base.max() overload for Levers to support irreversibility enforcement
  - Separated is_feasible() function for explicit constraint checking

**2025-12-05 - Phase 1 Started (Equation Extraction):**

- Starting with equation extraction for user review before implementation
- Will extract all equations (1-9) from Ceres et al. (2019) to docs/equations.md
- Awaiting user approval on equations before implementing any physics code

### Blockers

None currently.

### Decisions Made

- Using parametric structs for type flexibility
- One sentence per line in Markdown for better diffs
