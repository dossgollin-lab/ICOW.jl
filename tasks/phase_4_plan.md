# Phase 4 Plan: Core Physics - Costs and Event Damage

**Status:** Pending user approval

**Prerequisites:** Phase 3 (Geometry) - ✅ Completed

## Overview

Implement cost and damage calculation functions based on exact equations from the paper and C++ reference implementation.
This phase implements the core physics engine that will be used by both stochastic and EAD simulation modes.

## User Guidance (RESOLVED)

1. **Division by Zero in Equation 3 (P → 1.0)**:
   - **Decision**: Enforce P ∈ [0, 0.999] in optimization bounds and feasibility checks
   - Cost function can safely assume P < 1.0
   - Handle at boundary, not in calculation

2. **Division by Zero in Equation 1 (W → H_city)**:
   - **Decision**: Enforce W $\leq$ 0.999 * H_city in optimization bounds and feasibility checks
   - Physically: withdrawing entire city = infinite cost
   - Cost function can safely assume W < H_city

3. **Constrained Resistance (R $\geq$ B)**:
   - **Clarification**: Both R and B are relative to W (not absolute)
   - **Decision**: Allow R $\geq$ B and use Equation 5 (dominated but mathematically valid)
   - Optimizer will naturally avoid dominated strategies

4. **Dike Failure Mechanics**:
   - **EAD mode**: Use expected damage = `p_fail * damage_failed + (1 - p_fail) * damage_intact`
   - **Stochastic mode**: Sample from `Bernoulli(p_fail)` to determine failure
   - Implement expected damage version in Phase 4; stochastic sampling in Phase 6/7

5. **Simplified Damage Scope**:
   - **Decision**: Implement basic expected damage calculation without full zones
   - Use total city value after withdrawal (V_w) as basis
   - Full zone-based damage comes in Phase 6

## Implementation Plan

### Task 1: Set up files and structure

- [ ] Create `src/costs.jl` with module structure and imports
- [ ] Create `src/damage.jl` with module structure and imports
- [ ] Create `test/costs_tests.jl`
- [ ] Create `test/damage_tests.jl`
- [ ] Update `src/ICOW.jl` to include the new files

### Task 2: Implement withdrawal cost functions

Equations 1 & 2 from docs/equations.md (lines 42-52)

- [ ] Implement `calculate_withdrawal_cost(city, W)` - Equation 1
  - Handle division by zero when W → H_city
  - Return type should match input type (Float32/Float64)

- [ ] Implement `calculate_value_after_withdrawal(city, W)` - Equation 2
  - Simple formula, no edge cases
  - Used by resistance and zone calculations

- [ ] Write tests for withdrawal functions:
  - Zero test: W=0 should give C_W=0
  - Monotonicity: increasing W should increase cost
  - Boundary: W approaching H_city behavior
  - Type stability: Float32/Float64

### Task 3: Implement resistance cost functions

Equations 3, 4, 5 from docs/equations.md (lines 54-79)

- [ ] Implement `calculate_resistance_cost_fraction(city, P)` - Equation 3
  - Critical: Handle P → 1.0 safely (division by zero)
  - Include both linear and exponential terms
  - Include f_adj multiplier (hidden in C++ code)

- [ ] Implement `calculate_resistance_cost(city, levers)` - Equations 4 & 5
  - Check if R >= B to choose equation
  - Use V_w from calculate_value_after_withdrawal
  - Handle both constrained and unconstrained cases

- [ ] Write tests for resistance functions:
  - Zero test: R=0 and P=0 should give C_R=0
  - Monotonicity: increasing R and P should increase cost
  - Boundary: P → 1.0 handled safely
  - Constrained vs unconstrained: R < B vs R >= B
  - Type stability

### Task 4: Implement dike cost function

Equation 7 from docs/equations.md (line 108)

- [ ] Implement `calculate_dike_cost(city, D, B)` - Equation 7
  - Use calculate_dike_volume from geometry.jl (already implemented)
  - Simple: C_D = V_d * c_d
  - Note: B parameter needed for feasibility but not used in cost calc directly

- [ ] Write tests for dike cost:
  - Zero test: D=0 should give cost > 0 (due to D_startup)
  - Monotonicity: increasing D should increase cost
  - Type stability
  - Match volume test expectations

### Task 5: Implement total investment cost

- [ ] Implement `calculate_investment_cost(city, levers)` - Sum of C_W + C_R + C_D
  - Call all three component functions
  - Return total cost
  - Verify component functions are called correctly

- [ ] Write tests for total cost:
  - Zero test: all levers at 0 should give minimal cost
  - Component sum: verify C_total = C_W + C_R + C_D exactly
  - Monotonicity: increasing any lever should increase total cost
  - Type stability

### Task 6: Implement dike failure probability

Equation 8 from docs/equations.md (lines 129-139)

- [ ] Implement `calculate_dike_failure_probability(h_surge, D, city)` - Equation 8
  - Use corrected piecewise form (NOT buggy paper version)
  - Three cases: below threshold, linear rise, above dike
  - Use t_fail and p_min from city parameters
  - Handle D=0 case (no dike means certain failure if surge > 0)

- [ ] Write tests for dike failure:
  - Zero surge: should give p_min
  - Below threshold: should give p_min
  - Linear region: verify slope calculation
  - Above dike: should give 1.0
  - Edge cases: D=0, h_surge=0
  - Monotonicity: increasing surge should increase probability
  - Type stability

### Task 7: Implement simplified damage function

Simplified version for testing, full implementation in Phase 6

- [ ] Implement `calculate_event_damage(city, levers, surge)` - Simplified version
  - Use expected damage: `p_fail * damage_failed + (1 - p_fail) * damage_intact`
  - Base damage on V_w (value after withdrawal)
  - Use dike failure probability from Task 6
  - Use f_damage, f_intact, f_failed from city parameters
  - Document limitations and Phase 6 dependencies

- [ ] Write tests for event damage:
  - Zero surge: should give zero damage (or minimal)
  - Monotonicity: increasing surge should increase damage
  - Protection effect: higher D should reduce damage
  - Type stability

### Task 8: Create Quarto notebook with visualizations

- [ ] Create `docs/notebooks/phase4_costs.qmd`
- [ ] Visualize cost functions:
  - Withdrawal cost vs W (showing asymptote at H_city)
  - Resistance cost fraction vs P (showing exponential growth near 1.0)
  - Resistance cost: constrained (R $\geq$ B) vs unconstrained (R < B)
  - Dike cost vs D (showing startup cost effect)
  - Total investment cost surface (2D or 3D)

- [ ] Visualize damage functions:
  - Dike failure probability vs surge height (piecewise function)
  - Expected damage vs surge height for different dike heights
  - Protection effectiveness (damage reduction with investment)

- [ ] Include clear annotations explaining:
  - Physical meaning of each curve
  - Edge cases and asymptotic behavior
  - Trade-offs between strategies

### Task 9: Run full test suite

- [ ] Run all tests: `julia --project test/runtests.jl`
- [ ] Fix any failures
- [ ] Verify all tests pass
- [ ] Check code coverage (informal review)

### Task 10: Documentation and review

- [ ] Add docstrings to all functions with:
  - Brief description
  - Arguments with types
  - Returns with type
  - Equation reference
  - Edge case notes

- [ ] Review for code simplicity:
  - No unnecessary abstractions
  - Clear variable names matching equations
  - Comments only where logic isn't obvious

- [ ] Summary of changes for user

## Key Design Decisions

1. **Purity**: All functions are pure (no side effects, no state)
2. **Type parameterization**: Use `where {T<:Real}` to support Float32/Float64
3. **Equation references**: Each function references its equation number in docs/equations.md
4. **Safety first**: Handle edge cases explicitly rather than silently fail
5. **Test coverage**: Every function has zero, monotonicity, and boundary tests

## Dependencies

- **Completed**: CityParameters (Phase 1), Levers (Phase 2), calculate_dike_volume (Phase 3)
- **Blocks**: Phase 6 (full zone-based damage), Phase 7 (simulation engine)

## Success Criteria

- [ ] All cost functions implemented and tested
- [ ] Dike failure probability matches corrected Equation 8
- [ ] Simplified damage function ready for integration
- [ ] All tests pass
- [ ] No allocations in hot paths (verify with @time)
- [ ] User approval on approach

## Notes

- This phase implements mode-agnostic calculations (work for both stochastic and EAD)
- Simplified damage in this phase; full zone-based calculation comes in Phase 6
- Following exact C++ reference values where paper differs
- Division by zero protection is critical for optimization (solvers will test boundaries)
