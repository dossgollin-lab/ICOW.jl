# Phase 6: Zones & City Characterization

**Status:** Pending

**Prerequisites:** Phase 5 (Expected Annual Damage)

## Goal

Implement the complete zone-based city model from Figure 3 of the paper.

## Open Questions

1. **Zero-width zones:** How should we handle lever configurations that create zones with zero height?
2. **Basement flooding implementation:** How exactly should basement depth interact with zone flooding calculations?

## Deliverables

- [ ] `docs/zones.md` - Document zone structure from paper:
  - Zone definitions (0: withdrawn, 1: resistant, 2: unprotected, 3: dike-protected, 4: city heights)
  - Zone interaction logic
  - Damage calculation by zone
  - Figure 3 explanation

- [ ] `src/zones.jl` - Zone-based city model:
  - `CityZone` struct (boundaries, value density, damage modifier, protection status)
  - `calculate_city_zones(city, levers)` - Partition city into exactly 5 zones (fixed-size structure)
  - `calculate_zone_damage(zone, water_level, city)` - Damage per zone
  - **Performance requirement:** Use fixed-size immutable struct (e.g., `StaticArrays.SVector{5}` or `NTuple{5, CityZone}`)
  - **Important:** Do NOT filter out empty zones - set their Volume/Value to 0.0 instead

- [ ] `src/damage.jl` (update):
  - Replace simplified damage with `calculate_event_damage_full()`
  - Zone-by-zone damage accumulation
  - Special handling for dike-protected zone (stochastic failure)
  - Basement flooding effects

- [ ] Tests covering:
  - Zone structure for different lever combinations
  - Correct zone boundaries
  - Damage reduction with protection
  - Dike failure mechanics
  - Monotonicity of damage with surge height
  - Empty zones (zero volume/value) handled correctly

- [ ] `docs/notebooks/phase6_zones.qmd` - Quarto notebook illustrating Phase 6 features

## Key Design Decisions

- **Critical for performance:** Zone structure MUST be fixed-size to avoid allocations in hot loop
- Dynamic resizing kills performance during optimization (millions of evaluations)
- Always return exactly 5 zones, setting Volume=0 and Value=0 for unused zones
- Zone structure depends on lever settings (dynamic geometry)
- Protected zone (3) has probabilistic dike failure
- Resistance applies only up to dike base (or full height if no dike)
- Withdrawal zone (0) has zero value and damage
