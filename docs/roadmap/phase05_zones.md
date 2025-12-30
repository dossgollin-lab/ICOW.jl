# Phase 5: Zones & Event Damage

**Status:** Pending

**Prerequisites:** Phase 4 (Core Physics - Costs and Dike Failure)

## Goal

Implement the zone-based city model from Figure 3 and calculate event damage for a single surge.

## Open Questions

1. **Zero-width zones:** How should we handle lever configurations that create zones with zero height? (Proposed: keep all 5 zones, set value=0)
2. **Basement flooding:** How exactly should basement depth interact with zone flooding calculations?

## Deliverables

- [ ] `src/zones.jl` - Zone-based city model:
  - `ZoneGeometry` struct (boundaries, value, value_ratio)
  - `CityZones` struct using `NTuple{5, ZoneGeometry}` for fixed-size access
  - `calculate_city_zones(city, levers)` - Partition city into exactly 5 zones
  - **Performance requirement:** Fixed-size immutable struct, no allocations
  - **Important:** Do NOT filter out empty zones - set their value to 0.0 instead

- [ ] `src/damage.jl` - Event damage calculation:
  - `calculate_zone_damage(zone, h_surge, city)` - Damage per zone
  - `calculate_event_damage(h_surge, city, levers; dike_failed=false)` - Total damage
  - `calculate_event_damage_stochastic(h_surge, city, levers, rng)` - With random dike failure
  - Zone-by-zone damage accumulation
  - Special handling for dike-protected zone (stochastic failure)

- [ ] Tests covering:
  - Zone structure for different lever combinations
  - Correct zone boundaries
  - Zone values sum to V_w
  - Damage monotonicity with surge height
  - Dike failure increases Zone 3 damage
  - Empty zones handled correctly
  - Type stability

## Key Design Decisions

- **Critical for performance:** Zone structure MUST be fixed-size to avoid allocations in hot loop
- Always return exactly 5 zones, setting value=0 for unused zones
- Zone structure depends on lever settings (dynamic geometry)
- Protected zone (3) has probabilistic dike failure with `f_intact`/`f_failed` multipliers
- Resistance applies only up to dike base (or full height if no dike)
- Withdrawal zone (0) has zero value and damage
