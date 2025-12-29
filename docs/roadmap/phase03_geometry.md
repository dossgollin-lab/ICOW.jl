# Phase 3: Geometry

**Status:** Pending

**Prerequisites:** Phase 2 (Type System and Mode Design)

## Goal

Implement the geometrically complex dike volume calculation (Equation 6).

## Open Questions

1. **Numerical stability:** Are there parameter ranges where the equation becomes numerically unstable?
2. **Validation reference:** What tolerance should we use when comparing to trapezoidal approximation?

## Deliverables

- [ ] Extract Equation 6 from paper to `docs/equations.md` with LaTeX notation
- [ ] `src/geometry.jl` - Implement `calculate_dike_volume(city, D, B)` exactly as specified in paper
- [ ] Validation: Unit test against simple trapezoidal approximation to catch order-of-magnitude errors
- [ ] Comprehensive tests covering:
  - Zero height edge case
  - Monotonicity (volume increases with height)
  - Numerical stability
  - Trapezoidal approximation validation
- [ ] `docs/notebooks/phase3_geometry.qmd` - Quarto notebook illustrating Phase 3 features

## Key Design Decisions

- Equation 6 is geometrically complex due to irregular tetrahedrons on wedge slopes
- **Do not simplify the equation** - implement exactly as specified (no decomposition into helper functions)
- Validate correctness using trapezoidal approximation (sufficient to catch bugs without over-engineering)
- Total height includes startup costs: `h = D + D_startup`
- This is mode-agnostic physics (used by both stochastic and EAD modes)
