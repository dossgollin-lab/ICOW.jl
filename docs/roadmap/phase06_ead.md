# Phase 6: Expected Annual Damage Integration

**Status:** Completed

**Prerequisites:** Phase 5 (Zones & Event Damage)

## Goal

Implement integration of event damage over surge distributions for EAD mode.

## Resolved Questions

1. **Sample count defaults:** Default `n_samples=1000` for Monte Carlo (balanced accuracy and speed)
2. **Quadrature integration bounds:** Use infinite bounds `[-Inf, Inf]` to capture heavy tails in GEV (upper 0.1% tail = 17% of EAD!)
3. **Convergence tolerance:** MC-Quad agreement within ~5% for GEV storm surge
4. **QuadGK dependency:** Approved and added

## Deliverables

- [x] `src/damage.jl` (additions):
  - `calculate_expected_damage_given_surge(h_raw, city, levers)` - Analytical expectation over dike failure
  - `calculate_expected_damage_mc(city, levers, dist; n_samples=1000)` - Monte Carlo integration
  - `calculate_expected_damage_quad(city, levers, dist)` - Quadrature integration
  - `calculate_expected_damage(city, levers, forcing, year; method=:quad)` - Main dispatcher interface

- [x] Tests covering:
  - Zero surge distributions
  - Dirac and narrow Normal distributions
  - Monte Carlo convergence with sample count
  - Agreement between MC and quadrature methods
  - Monotonicity with distribution parameters
  - Type stability (Float32/Float64)
  - Dispatcher interface with DistributionalForcing
  - Expected damage bounds checking

## Key Design Decisions

- **Two-level integration:** Analytical expectation over dike failure, then numerical integration over surge distribution
- **Monte Carlo:** `mean([calculate_expected_damage_given_surge(h, ...) for h in samples])`
- **Quadrature:** Integrate `pdf(h) * calculate_expected_damage_given_surge(h, ...)` using QuadGK.jl
- **Default method:** QuadGK (`:quad`) for deterministic, efficient integration (see benchmark results with GEV)
- **Type handling:** QuadGK may return Float64 even with Float32 inputs (acceptable)

## Implementation Notes

All 167 tests pass. Functions are pure, type-stable, and allocation-efficient.
