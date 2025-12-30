# Phase 1: Parameters & Validation

**Status:** Completed

**Prerequisites:** None

## Goal

Establish the foundational parameter types and constraint validation.

## Deliverables

- [x] `src/parameters.jl` - Parameterized `CityParameters{T}` struct with all exogenous parameters from Table C.3
- [x] `src/types.jl` - Parameterized `Levers{T}` struct with physical constraint validation
- [x] `docs/parameters.md` - Documentation of all parameters with symbols, units, and physical interpretation
- [x] Validation function `validate_parameters()` for physical consistency
- [x] Feasibility check `is_feasible()` for lever constraints
- [x] Comprehensive tests covering:
  - Parameter construction and validation
  - Lever constraint enforcement
  - Type conversions and defaults
  - Edge cases and boundary conditions

## Key Design Decisions

- Use `Base.@kwdef` for convenient keyword construction with defaults
- Parameterize by `T<:Real` to avoid writing `Float64` everywhere
- Strict validation with `@assert` in constructors
- `Base.max()` overload for irreversibility enforcement
