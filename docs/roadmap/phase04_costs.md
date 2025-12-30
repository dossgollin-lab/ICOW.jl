# Phase 4: Core Physics - Costs and Dike Failure

**Status:** Completed

**Prerequisites:** Phase 3 (Geometry)

## Goal

Implement cost functions (Equations 1-7) and dike failure probability (Equation 8) based on exact equations from the paper.
Event damage functions (Equation 9) are deferred to Phase 6 where zones are fully implemented.

**Note:** `docs/equations.md` already contains all equations (1-9) from Ceres et al. (2019) in LaTeX.

## Decisions (RESOLVED)

1. **Division by zero:** Enforce P < 0.999 and W < 0.999*H_city in optimization bounds, not in cost functions
2. **Constrained resistance:** Allow R ≥ B, use Equation 5 (dominated but mathematically valid)
3. **Dike failure probability:** Implement calculation only; damage application deferred to Phase 6
4. **Event damage:** NO implementation in Phase 4 - requires zones (Phase 6)
5. **Scope:** Costs (complete) + Failure probability (complete) only

## Deliverables

- [x] `docs/equations.md` - Already complete with all equations (1-9)

- [x] `src/costs.jl` - Cost calculation functions (Equations 1-7):
  - `calculate_withdrawal_cost(city, W)` - Equation 1
  - `calculate_value_after_withdrawal(city, W)` - Equation 2
  - `calculate_resistance_cost_fraction(city, P)` - Equation 3
  - `calculate_resistance_cost(city, levers)` - Equations 4-5 (handles R ≥ B)
  - `calculate_dike_cost(city, D, B)` - Equation 7 (uses Phase 3 volume)
  - `calculate_investment_cost(city, levers)` - Total cost
  - `calculate_effective_surge(h_raw, city)` - Surge preprocessing

- [x] `src/costs.jl` - Dike failure probability (Equation 8):
  - `calculate_dike_failure_probability(h_surge, D, city)` - Corrected piecewise form

- [x] Comprehensive tests (`test/costs_tests.jl`):
  - Cost monotonicity (increasing levers → increasing costs)
  - Zero inputs → zero outputs (or minimal for D=0 due to startup)
  - Component validation (sum equals total)
  - Type stability (Float32/Float64)
  - Constrained vs unconstrained resistance (R < B vs R ≥ B)

## Key Design Decisions

- **Costs only in Phase 4:** Full, correct implementation of Equations 1-7
- **Failure probability only:** Equation 8 implemented, but damage application deferred to Phase 6
- **No half-measures:** Event damage requires zones; moved entirely to Phase 6
- **Boundary safety:** Division by zero prevented via optimization bounds, not function logic
- **Mode-agnostic:** All functions work for both stochastic and EAD modes
