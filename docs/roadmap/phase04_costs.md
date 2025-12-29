# Phase 4: Core Physics - Costs and Event Damage

**Status:** Pending

**Prerequisites:** Phase 3 (Geometry)

## Goal

Implement cost and damage functions based on exact equations from the paper.

**Prerequisite:** Complete `docs/equations.md` with all equations (1-9) before implementation.

## Open Questions

1. **Edge case handling:** How should we handle division by zero cases (return Inf, throw error, clamp)?
2. **Numerical tolerances:** What tolerance for floating point comparisons in physical constraints?
3. **Constrained resistance:** When R > B (dominated strategy), should we warn, clamp silently, or allow?
4. **Dike failure mechanics:** Should failure be deterministic (use probability as damage weight) or stochastic (sample from probability)?
5. **Simplified damage scope:** How much functionality should the Phase 4 damage function have before full zones in Phase 6?

## Deliverables

- [ ] `docs/equations.md` - All equations from Ceres et al. (2019) in LaTeX:
  - Equation 1: Withdrawal cost
  - Equation 2: City value after withdrawal
  - Equation 3: Resistance cost fraction
  - Equations 4-5: Resistance cost (unconstrained and constrained)
  - Equation 6: Dike volume (from Phase 3)
  - Equation 7: Dike cost
  - Equation 8: Dike failure probability
  - Equation 9: Damage by zone
  - Symbol definitions and units

- [ ] `src/costs.jl` - Cost calculation functions:
  - `calculate_withdrawal_cost(city, W)`
  - `calculate_value_after_withdrawal(city, W)`
  - `calculate_resistance_cost_fraction(city, P)` **with bounds checking**
  - `calculate_resistance_cost(city, levers)`
  - `calculate_dike_cost(city, D, B)`
  - `calculate_investment_cost(city, levers)` (total)
  - **Boundary safety:** Implement `check_bounds` or `clamp` logic to ensure P < 1.0 before evaluation

- [ ] `src/damage.jl` - Event damage calculation:
  - `calculate_event_damage(city, levers, surge)` (simplified version)
  - `calculate_dike_failure_probability(surge_height, D, threshold)`
  - Helper functions for damage components

- [ ] Comprehensive tests covering:
  - Cost monotonicity (increasing levers $\to$ increasing costs)
  - Zero inputs $\to$ zero outputs
  - **Boundary cases:** P $\to$ 1.0 handled safely (no division by zero crashes)
  - Edge cases (division by zero avoidance in withdrawal)
  - Cost component validation (sum equals total)

- [ ] `docs/notebooks/phase4_costs.qmd` - Quarto notebook illustrating Phase 4 features

## Key Design Decisions

- **Critical:** Equation 3 has `(1 - P)` denominator - must prevent $P \geq 1.0$ to avoid division by zero in optimization
- Event damage calculation is mode-agnostic (single surge realization)
- Used directly by stochastic mode
- Used indirectly by EAD mode (integrated over distribution)
- Simplified version in this phase; full zone-based calculation in Phase 6
