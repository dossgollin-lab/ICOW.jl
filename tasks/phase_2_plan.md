# Phase 2: Type System and Simulation Mode Design

## Summary

Define the type system architecture for dual-mode simulation (stochastic and EAD modes).
This phase establishes abstract types and concrete implementations for forcing, state, and policies.

## Design Decisions (User Confirmed)

- **Scope**: Minimal essential - only core types and basic constructors. Defer convenience helpers.
- **State semantics**: Mutable states (update in-place) for performance in hot simulation loops.

## Todo List

- [x] Add abstract type hierarchy to `src/types.jl`
- [x] Create `src/forcing.jl` with StochasticForcing and DistributionalForcing
- [x] Create `src/states.jl` with StochasticState and EADState (mutable)
- [x] Create `src/policies.jl` with AbstractPolicy and StaticPolicy
- [x] Update `src/ICOW.jl` with includes and exports
- [x] Create `test/forcing_tests.jl`
- [x] Create `test/states_tests.jl`
- [x] Create `test/policies_tests.jl`
- [x] Update `test/runtests.jl` to include new test files
- [x] Create `docs/simulation_modes.md`
- [x] Create `docs/notebooks/phase2_type_system.qmd`
- [x] Run tests: `julia --project test/runtests.jl`
- [x] Update `docs/roadmap/README.md` to mark Phase 2 Completed

## Implementation Details

### Abstract Types (`src/types.jl`)

Add at top of file before Levers:

```julia
abstract type AbstractForcing{T<:Real} end
abstract type AbstractSimulationState{T<:Real} end
abstract type AbstractPolicy{T<:Real} end
```

### Forcing Types (`src/forcing.jl`)

**StochasticForcing{T}**: Realized surge matrix `[n_scenarios x n_years]`

```julia
struct StochasticForcing{T<:Real} <: AbstractForcing{T}
    surges::Matrix{T}
    start_year::Int
end
```

**DistributionalForcing{T,D}**: Vector of Distribution objects per year

```julia
struct DistributionalForcing{T<:Real, D<:Distribution} <: AbstractForcing{T}
    distributions::Vector{D}
    start_year::Int
end
```

Access functions: `n_scenarios(f)`, `n_years(f)`, `get_surge(f, scenario, year)`, `get_distribution(f, year)`

### State Types (`src/states.jl`)

**StochasticState{T}** (mutable):

```julia
mutable struct StochasticState{T<:Real} <: AbstractSimulationState{T}
    current_levers::Levers{T}
    accumulated_cost::T
    accumulated_damage::T
    current_year::Int
end
```

**EADState{T}** (mutable):

```julia
mutable struct EADState{T<:Real} <: AbstractSimulationState{T}
    current_levers::Levers{T}
    accumulated_cost::T
    accumulated_ead::T
    current_year::Int
end
```

**Outer constructors** (initialize accumulators to zero):

```julia
StochasticState(levers::Levers{T}) where {T} = StochasticState(levers, zero(T), zero(T), 1)
EADState(levers::Levers{T}) where {T} = EADState(levers, zero(T), zero(T), 1)
```

### Policy Types (`src/policies.jl`)

**StaticPolicy{T}**: Fixed lever settings

```julia
struct StaticPolicy{T<:Real} <: AbstractPolicy{T}
    levers::Levers{T}
end

(policy::StaticPolicy)(state, forcing, year) = policy.levers
parameters(policy::StaticPolicy) = [policy.levers.W, policy.levers.R, policy.levers.P, policy.levers.D, policy.levers.B]
```

### Documentation (`docs/simulation_modes.md`)

Brief conceptual documentation:

- Stochastic vs EAD modes
- When to use each
- Powell framework connection

### Quarto Notebook (`docs/notebooks/phase2_type_system.qmd`)

**Forcing Visualization Section** (validates matrix orientation and distribution logic):

**StochasticForcing - Spaghetti Plot:**

- X-axis: Year
- Y-axis: Surge Height
- Plot 10-20 random scenario lines in grey, mean in bold red
- Validates: matrix orientation `[scenarios, years]` is correct, scale is realistic

**DistributionalForcing - PDF Comparison:**

- Plot PDF for Year 1 vs Year 50
- Validates: distribution shifts right if SLR included, or stays static
- Proves distribution logic is working

## Review

**Completed:** All Phase 2 deliverables implemented and tested.

**Files created:**

- `src/forcing.jl` - StochasticForcing and DistributionalForcing types
- `src/states.jl` - StochasticState and EADState (mutable with convenience constructors)
- `src/policies.jl` - AbstractPolicy interface and StaticPolicy
- `test/forcing_tests.jl`, `test/states_tests.jl`, `test/policies_tests.jl`
- `docs/simulation_modes.md` - Conceptual documentation
- `docs/notebooks/phase2_type_system.qmd` - Quarto notebook with visualizations

**Files modified:**

- `src/types.jl` - Added abstract type hierarchy
- `src/ICOW.jl` - Added includes and exports
- `test/runtests.jl` - Added Phase 2 test includes

**Test results:** 232 tests passing

**Notes:**

- Quarto notebook uses CairoMakie for visualizations (may need package installation)
- States are mutable as per user preference for simulation performance
