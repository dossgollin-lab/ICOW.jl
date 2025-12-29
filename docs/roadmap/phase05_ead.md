# Phase 5: Expected Annual Damage Calculation

**Status:** Pending

**Prerequisites:** Phase 4 (Core Physics - Costs and Event Damage)

## Goal

Implement integration of event damage over surge distributions for EAD mode.

## Open Questions

1. **Sample count defaults:** What's the default `n_samples` for Monte Carlo? Trade-off between accuracy and memory.
2. **Quadrature integration bounds:** For unbounded distributions, what upper quantile should we integrate to?
3. **Convergence tolerance:** What relative tolerance is acceptable for mode convergence tests?

## Deliverables

- [ ] `src/damage.jl` (additions):
  - `calculate_expected_damage(city, levers, forcing, year)`
  - Support both Monte Carlo (cached samples) and quadrature integration
  - Dispatch on `forcing.integration_method`

- [ ] Tests covering:
  - Monte Carlo integration using cached samples
  - Numerical quadrature integration
  - Agreement between integration methods
  - Convergence to stochastic mean (Law of Large Numbers)
  - Monotonicity over time for non-stationary distributions

- [ ] `docs/notebooks/phase5_ead.qmd` - Quarto notebook illustrating Phase 5 features

## Key Design Decisions

- Uses cached samples from `DistributionalForcing` for efficiency
- Monte Carlo: `mean(calculate_event_damage.(samples))`
- Quadrature: Integrate `pdf(surge) * damage(surge)` using QuadGK.jl
- Critical validation: EAD $\approx$ mean(stochastic damages) for same distribution
