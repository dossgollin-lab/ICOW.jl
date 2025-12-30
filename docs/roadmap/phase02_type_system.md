# Phase 2: Type System and Simulation Mode Design

**Status:** Completed

**Prerequisites:** Phase 1 (Parameters & Validation)

## Goal

Define the type system architecture for dual-mode simulation before implementing physics.

This phase establishes the framework for both stochastic and EAD modes without implementing the full physics.
It answers fundamental design questions about how forcing, state, and policies interact.

## Open Questions

1. **Scope of initial implementation:** Which convenience constructors and helpers are essential vs future enhancements?
2. **State update semantics:** Should state fields be updated in-place or should we return modified copies?

## Deliverables

- [ ] `docs/simulation_modes.md` - Comprehensive documentation explaining:
  - Conceptual overview of stochastic vs EAD modes
  - When to use each mode (decision guide)
  - Powell framework connection (state, decision, exogenous info, transition, objective)
  - Expected convergence behavior
  - Performance characteristics and limitations

- [ ] `src/types.jl` (additions) - Abstract type hierarchy:
  - `AbstractForcing{T<:Real}` interface specification
  - `AbstractSimulationState{T<:Real}`
  - `AbstractPolicy{T<:Real}`

- [ ] `src/forcing.jl` - Forcing types for both modes:
  - `StochasticForcing{T}` - Contains realized surge matrix `[n_scenarios, n_years]`
  - `DistributionalForcing{T,D}` - Contains vector of `Distribution` objects and cached samples
  - `ModelClock` or equivalent structure for mapping simulation years to calendar years/climate trends
  - `calendar_year()` and related temporal mapping functions
  - Constructors and validation
  - **Note:** Forcing objects represent aleatory (stochastic) uncertainty only

- [ ] `src/states.jl` - State types for both modes:
  - `StochasticState{T}` - Tracks realized surges and damages
  - `EADState{T}` - Tracks expected annual damages
  - Constructors from forcing objects

- [ ] `src/policies.jl` - Policy interface:
  - **Callable struct pattern:** `(policy::AbstractPolicy)(state, forcing, year) -> Levers`
  - **Parameter extraction:** `parameters(policy) -> AbstractVector` for optimization
  - **Reconstruction:** Constructor from parameter vector `PolicyType(θ::AbstractVector)`
  - `StaticPolicy{T}` implementation (parameters $\theta$ = lever values directly)
  - Documentation of what policies can observe (state, forcing, current year)

- [ ] `src/parameters.jl` (update):
  - Parameterize `CityParameters{T}` with concrete scalar fields
  - **Important:** Fields remain concrete scalars (not Distributions)
  - Epistemic (deep) uncertainty handled by generating/sampling multiple `CityParameters` objects externally

- [ ] Comprehensive tests covering:
  - Type construction and conversions
  - State initialization from forcing
  - Policy callable interface
  - Type stability verification
  - Calendar year calculations and clock functionality

## Key Design Decisions

- **Modular uncertainty representation:** `AbstractForcing` interface allows "plug and play" of different uncertainty structures (e.g., deep uncertainty with drifting parameters)
- **Temporal mapping:** Forcing objects include clock/mapping to link simulation steps to calendar years for non-stationary trends
- **Epistemic vs aleatory separation:** `CityParameters` stays concrete; deep uncertainty explored by running multiple scenarios with different parameter sets
- Policies receive full forcing object (maximum flexibility for observing exogenous info)
- Sample matrix oriented as `n_scenarios × n_years` for efficient scenario iteration
- Pre-generated cached samples for deterministic, efficient EAD evaluation

## Implementation Notes

**USER REVIEW CHECKPOINT:** Do not proceed to Phase 3 until type system is approved.
