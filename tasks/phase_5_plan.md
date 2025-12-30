# Phase 5: Zones & Event Damage

**Status:** Planning

## Summary

Implement zone-based city model (Figure 3) and event damage calculation for a single surge.
This phase creates the foundation for all damage calculations.

## Prerequisites

- Phase 4 (Costs): Provides `calculate_effective_surge` and `calculate_dike_failure_probability`

## Conceptual Overview

### The Wedge Model

The city sits on a "wedge" - a sloped surface rising from sea level (elevation 0) to the city peak (elevation $H_{city}$).
Value is distributed uniformly across this wedge.
When a surge occurs, water floods from the bottom up.

### Coordinate System

All elevations are **absolute** (measured from sea level = 0):

- `h_surge`: Effective surge height after seawall/runup (from Phase 4)
- Zone boundaries are absolute elevations
- Levers W, R, B, D define zone boundaries relative to each other

### Zone Structure

The city is partitioned into 5 zones based on lever settings:

| Zone | Absolute Elevation Range | Width | Description |
|------|--------------------------|-------|-------------|
| 0 | 0 to W | W | Withdrawn (no value) |
| 1 | W to W + min(R,B) | min(R,B) | Resistant |
| 2 | W + min(R,B) to W + B | max(0, B-R) | Unprotected gap |
| 3 | W + B to W + B + D | D | Dike protected |
| 4 | W + B + D to $H_{city}$ | $H_{city}$ - W - B - D | Above dike |

**Key observations:**

- Zone 0 has no value (people/assets relocated)
- Zone 2 only exists if R < B (otherwise width = 0)
- Zone 3 has stochastic dike failure
- All zones always exist in the struct (some may have width/value = 0)

### Damage Logic

For a given surge height `h_surge`:

1. **No flooding if h_surge $\leq$ W** - surge doesn't reach remaining city
2. **Damage per zone** uses C++ formula with basement depth (see Implementation Notes)
3. **Zone 1 damage reduced** by factor $(1-P)$ - resistant buildings
4. **Zone 3 damage** depends on dike state:
   - If dike intact: multiply by $f_{intact}$ (0.03)
   - If dike failed: multiply by $f_{failed}$ (1.5)
5. **Threshold penalty** if total damage exceeds $d_{thresh}$

### Dike Failure Decision

The dike can fail in two ways:

1. **Overtopping**: If $h_{surge} \geq W + B + D$, dike is overtopped → always fails
2. **Structural failure**: If $h_{surge} < W + B + D$, dike may fail probabilistically per Equation 8

## Open Questions for User

1. **Zero-width zones**: Confirm: keep all 5 zones, set value=0 for empty ones? (This ensures fixed-size struct)

## Deliverables

### File: `src/zones.jl`

Uses Julia dispatch - each zone type knows its own damage behavior.

- [ ] `abstract type AbstractZone{T} end` - base type for dispatch

- [ ] Concrete zone types (all with fields `z_low::T`, `z_high::T`, `value::T`):
  - `WithdrawnZone{T} <: AbstractZone{T}` - Zone 0, no damage
  - `ResistantZone{T} <: AbstractZone{T}` - Zone 1, damage × $(1-P)$
  - `UnprotectedZone{T} <: AbstractZone{T}` - Zone 2, standard damage
  - `DikeProtectedZone{T} <: AbstractZone{T}` - Zone 3, uses dike factor
  - `AboveDikeZone{T} <: AbstractZone{T}` - Zone 4, standard damage

- [ ] `CityZones{T}` - wrapper around heterogeneous `Tuple`
  - Type: `Tuple{WithdrawnZone{T}, ResistantZone{T}, UnprotectedZone{T}, DikeProtectedZone{T}, AboveDikeZone{T}}`
  - Constructor validates: zones ordered, values non-negative
  - Indexable: `zones[i]` returns zone i

- [ ] `calculate_city_zones(city, levers)` - partition city into 5 zones
  - Computes zone boundaries from levers
  - Computes zone values from equations.md formulas
  - Returns `CityZones` (always 5 zones, some may have value=0)

### File: `src/damage.jl`

- [ ] `calculate_zone_damage(zone::AbstractZone, h_surge, city, levers; dike_failed=false)`
  - Dispatches on zone type - each type implements its own method
  - Uses C++ damage formula with basement depth (see Implementation Notes)
  - `WithdrawnZone`: always returns 0
  - `ResistantZone`: multiplies by $(1-P)$
  - `DikeProtectedZone`: multiplies by $f_{intact}$ or $f_{failed}$
  - Others: standard damage formula

- [ ] `calculate_event_damage(h_surge, city, levers; dike_failed=false)` - total damage
  - Compute zones
  - Sum damage across all zones
  - Apply threshold penalty if total > $d_{thresh}$

- [ ] `calculate_event_damage_stochastic(h_surge, city, levers, rng)` - with random dike failure
  - Compute $p_{fail}$ using Phase 4's `calculate_dike_failure_probability`
  - Sample dike failure: `rand(rng) < p_fail`
  - Call `calculate_event_damage` with result

### File: `test/zones_tests.jl`

- [ ] Zone boundaries correct for W=0, R=0, B=0, D=0 (no protection)
- [ ] Zone boundaries correct for W=5, R=3, B=5, D=4 (typical case)
- [ ] Zone boundaries correct for R > B (Zone 2 has zero width)
- [ ] Zone values sum to $V_w$ (value after withdrawal)
- [ ] Type stability

### File: `test/damage_tests.jl`

- [ ] h_surge = 0 → damage = 0
- [ ] h_surge < W → damage = 0 (surge below city)
- [ ] Damage monotonically increases with h_surge
- [ ] Resistance reduces Zone 1 damage (compare P=0 vs P=0.5)
- [ ] Dike failure increases Zone 3 damage ($f_{failed}$ > $f_{intact}$)
- [ ] Threshold penalty applies when damage > $d_{thresh}$
- [ ] Total damage bounded by city value
- [ ] Type stability

## Implementation Notes

### Zone Value Formulas (from equations.md)

```julia
V_w = calculate_value_after_withdrawal(city, W)  # from Phase 4
remaining_height = H_city - W

Val_Z0 = 0  # withdrawn, no value
Val_Z1 = V_w * r_unprot * min(R, B) / remaining_height
Val_Z2 = V_w * r_unprot * max(0, B - R) / remaining_height
Val_Z3 = V_w * r_prot * D / remaining_height
Val_Z4 = V_w * (remaining_height - B - D) / remaining_height
```

### C++ Damage Formula (MUST match exactly)

From C++ `CalculateDamageResiliantUnprotectedZone1` and similar functions.
Uses basement depth in damage calculation:

```julia
# washOver = surge height above zone bottom = max(0, h_surge - z_low)
# Basement = b_basement (3.0m)
# BH = H_bldg (30.0m)
# zone_height = z_high - z_low

if washOver <= 0
    damage = 0
elseif washOver < zone_height  # partial flooding
    damage = zone_value * f_damage * washOver * (washOver/2 + Basement) / (BH * zone_height)
else  # full flooding (surge above zone top)
    damage = zone_value * f_damage * (Basement + zone_height/2) / BH
end
```

This accounts for:

- Flood depth in zone (washOver)
- Additional depth from basement flooding (Basement)
- Normalized by building height and zone height

### Zone-Specific Modifiers

- **ResistantZone**: Multiply damage by $(1-P)$ where P = `levers.P`
- **DikeProtectedZone**: Multiply by $f_{intact}$ or $f_{failed}$

### Threshold Damage Formula

```julia
if total_damage > d_thresh
    total_damage += (f_thresh * (total_damage - d_thresh))^gamma_thresh
end
```

### Performance Requirements

- `CityZones` uses heterogeneous Tuple (fixed-size, no allocations)
- All zone types are concrete and immutable
- Dispatch resolved at compile time for type stability

## Todo Checklist

- [ ] Resolve open questions with user
- [ ] Create `src/zones.jl`
  - [ ] `AbstractZone{T}` and 5 concrete zone types
  - [ ] `CityZones{T}` wrapper with validation
  - [ ] `calculate_city_zones(city, levers)`
- [ ] Create `src/damage.jl`
  - [ ] `calculate_zone_damage` methods for each zone type
  - [ ] `calculate_event_damage(h_surge, city, levers; dike_failed)`
  - [ ] `calculate_event_damage_stochastic(h_surge, city, levers, rng)`
- [ ] Update `src/ICOW.jl` to include new files
- [ ] Create `test/zones_tests.jl`
- [ ] Create `test/damage_tests.jl`
- [ ] Run tests: `julia --project test/runtests.jl`

## Review

(To be filled after implementation)
