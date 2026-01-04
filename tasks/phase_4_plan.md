# Phase 4: Core Physics - Costs and Dike Failure

**Status:** Completed

## Summary

Implemented cost functions (Equations 1-7) and dike failure probability (Equation 8).
Event damage deferred to Phase 6 where zones are available.

## Key Decisions

1. **Division by zero**: Enforce P < 0.999 and W < 0.999*H_city in optimization bounds
2. **Constrained resistance**: Allow R >= B, use Equation 5 (dominated but valid)
3. **Dike cost**: D=0 returns 0 (no dike = no cost)
4. **Equation 6**: Uses correct sqrt(T) formula with C++ slope definition

## Functions Implemented

- `calculate_withdrawal_cost(city, W)` - Equation 1
- `calculate_value_after_withdrawal(city, W)` - Equation 2
- `calculate_resistance_cost_fraction(city, P)` - Equation 3
- `calculate_resistance_cost(city, levers)` - Equations 4-5
- `calculate_dike_cost(city, D)` - Equation 7
- `calculate_investment_cost(city, levers)` - Total cost
- `calculate_effective_surge(h_raw, city)` - Surge preprocessing
- `calculate_dike_failure_probability(h_surge, D, city)` - Equation 8

## Test Coverage

All functions tested with zero/edge cases, monotonicity, and type stability.
See `test/costs_tests.jl` (101 lines, 30+ tests).
