# Phase 6: Expected Annual Damage Integration

**Status:** Pending

**Prerequisites:** Phase 5 (Zones & Event Damage)

## Goal

Implement integration of event damage over surge distributions for EAD mode.

## Open Questions

1. **Sample count defaults:** What's the default `n_samples` for Monte Carlo? Trade-off between accuracy and speed.
2. **Quadrature integration bounds:** For unbounded distributions, what upper quantile should we integrate to?
3. **Convergence tolerance:** What relative tolerance is acceptable for mode convergence tests?
4. **QuadGK dependency:** Need approval to add QuadGK.jl for numerical quadrature.

## Deliverables

- [ ] `src/damage.jl` (additions):
  - `calculate_expected_damage_mc(city, levers, dist; n_samples=1000)` - Monte Carlo integration
  - `calculate_expected_damage_quad(city, levers, dist)` - Quadrature integration (if QuadGK approved)
  - `calculate_expected_damage(city, levers, forcing, year; method=:mc)` - Main interface

- [ ] Tests covering:
  - Monte Carlo integration returns reasonable values
  - Numerical quadrature integration (if implemented)
  - Agreement between integration methods
  - Convergence to stochastic mean (Law of Large Numbers)
  - Monotonicity over time for non-stationary distributions

## Key Design Decisions

- Monte Carlo: `mean(calculate_event_damage.(samples, ...))`
- Quadrature: Integrate `pdf(surge) * damage(surge)` using QuadGK.jl
- Critical validation: EAD $\approx$ mean(stochastic damages) for same distribution
- Both methods should be available; Monte Carlo is the default
