# Model Parameters

This document describes all parameters used in the iCOW (Island City on a Wedge) model.
Parameter values are based on Tables C.3 and C.4 from Ceres et al. (2019), Appendix C.

## City Geometry

| Parameter | Symbol | Default Value | Units | Description |
|-----------|--------|---------------|-------|-------------|
| `total_value` | $v_i$ | $1.5 \times 10^{12}$ | $ | Initial total economic value of the city |
| `building_height` | $h$ | 30.0 | m | Representative building height |
| `city_max_height` | $H_{city}$ | 17.0 | m | Maximum elevation of city above seawall |
| `city_depth` | $D_{city}$ | 2000.0 | m | Distance from seawall to highest point |
| `city_length` | $W_{city}$ | 43000.0 | m | Length of the seawall/coastline |
| `seawall_height` | $H_{seawall}$ | 1.75 | m | Height of existing seawall |
| `city_slope` | $S$ | 0.0085 | m/m | Slope of the wedge (= $H_{city} / D_{city}$) |

The city is modeled as a wedge rising from the seawall at elevation 0 to the maximum city height over a horizontal distance of `city_depth`.
The city extends for `city_length` along the coast, forming a U-shaped geometry when dikes are built.

## Dike Parameters

| Parameter | Symbol | Default Value | Units | Description |
|-----------|--------|---------------|-------|-------------|
| `dike_startup_height` | $D_{startup}$ | 3.0 | m | Equivalent height representing startup/mobilization costs |
| `dike_top_width` | $w_d$ | 4.0 | m | Width of the top of the dike |
| `dike_side_slope` | $s$ | 0.5 | m/m | Slope of dike sides (horizontal/vertical) |
| `dike_cost_per_m3` | $c_{dpv}$ | 10.0 | $/m³ | Cost per cubic meter of dike material |
| `dike_value_ratio` | $r_{value}$ | 1.1 | - | Multiplier for city value in dike-protected areas |

The startup height is added to the actual dike height when calculating volume (Equation 6), representing fixed costs for mobilization, permitting, and initial construction.

## Withdrawal Parameters

| Parameter | Symbol | Default Value | Units | Description |
|-----------|--------|---------------|-------|-------------|
| `withdrawal_factor` | $f_w$ | 1.0 | - | Cost adjustment factor for withdrawal |
| `withdrawal_fraction` | $f_l$ | 0.01 | - | Fraction of displaced infrastructure that leaves vs. relocates |

Withdrawal involves relocating infrastructure from low-lying areas to higher elevations.
The cost depends on the area withdrawn and the remaining area available for relocation (Equation 1).
Some fraction (`withdrawal_fraction`) of displaced value leaves the city entirely, reducing total city value.

## Resistance Parameters

| Parameter | Symbol | Default Value | Units | Description |
|-----------|--------|---------------|-------|-------------|
| `resistance_linear_factor` | $f_{lin}$ | 0.35 | - | Linear component of resistance cost |
| `resistance_exp_factor` | $f_{exp}$ | 0.9 | - | Exponential component of resistance cost |
| `resistance_threshold` | $t_{exp}$ | 0.6 | - | Threshold where exponential costs begin |
| `basement_depth` | $b$ | 3.0 | m | Representative basement depth for buildings |

Resistance (flood-proofing) involves hardening buildings against flooding.
The cost per unit value increases non-linearly with the resistance percentage (Equation 3).
At low percentages, costs are linear.
Above the threshold, costs increase exponentially as complete flood-proofing becomes prohibitively expensive.

## Damage Parameters

| Parameter | Symbol | Default Value | Units | Description |
|-----------|--------|---------------|-------|-------------|
| `damage_fraction` | $f_{damage}$ | 0.39 | - | Fraction of inundated building value lost to damage |
| `protected_damage_factor` | $f_{fail}$ | 1.3 | - | Damage multiplier when dike fails (vs. no dike) |
| `dike_failure_threshold` | $t_{df}$ | 0.95 | - | Water level threshold (as fraction of D) where failure probability increases |
| `threshold_damage_level` | $t_{damage}$ | 0.00267 | - | Minimum damage threshold (1/375 of city value) |
| `wave_runup_factor` | $r_{wave}$ | 1.1 | - | Factor by which surge increases due to wave action |

Damage is calculated zone-by-zone based on inundated volume (Equation 9).
When water overtops a seawall, wave action amplifies the effective surge height by `wave_runup_factor`.
When a dike fails catastrophically, damage is increased by `protected_damage_factor` due to sudden inundation and debris impact.

## Economic Parameters

| Parameter | Symbol | Default Value | Units | Description |
|-----------|--------|---------------|-------|-------------|
| `discount_rate` | $r$ | 0.04 | yr⁻¹ | Annual discount rate for present value calculations |

All costs and damages are discounted to present value using discount factor $(1 + r)^{-t}$ where $t$ is the number of years.

## Simulation Parameters

| Parameter | Symbol | Default Value | Units | Description |
|-----------|--------|---------------|-------|-------------|
| `n_years` | $T$ | 50 | years | Simulation time horizon |

The model simulates 50 years of annual storm surge events.
This matches the typical planning horizon for coastal infrastructure.

## Parameter Validation

When constructing a `CityParameters` object, the following consistency checks are performed:

1. `total_value > 0` (city must have positive value)
2. `city_max_height > seawall_height` (city must be higher than existing seawall)
3. `0 < discount_rate < 1` (discount rate must be in valid range)
4. `city_slope ≈ city_max_height / city_depth` (slope must match geometry)
5. `0 ≤ resistance_threshold ≤ 1` (threshold must be valid percentage)
6. `n_years > 0` (must simulate at least one year)

## Decision Levers

In addition to fixed parameters, the model has five decision levers that can be optimized:

| Lever | Symbol | Units | Description | Typical Range |
|-------|--------|-------|-------------|---------------|
| `withdraw_h` | $W$ | m | Height below which to withdraw | [0, 8.5] |
| `resist_h` | $R$ | m | Height up to which to flood-proof | [0, 13.6] |
| `resist_p` | $P$ | - | Percentage of resistance to apply | [0, 1] |
| `dike_h` | $D$ | m | Height of dike above base | [0, 15] |
| `dike_base_h` | $B$ | m | Elevation of dike base | [0, 14] |

### Lever Constraints

The decision levers must satisfy the following physical constraints:

1. $B + D \leq H_{city}$ (dike top cannot exceed city height)
2. $W \leq B$ (withdrawal cannot exceed dike base elevation)
3. $0 \leq P \leq 1$ (resistance percentage must be valid)
4. $W, R, D, B \geq 0$ (all heights must be non-negative)

These constraints are enforced by the `Levers` constructor and checked by the `is_feasible()` function.

## References

Ceres, R. L., Dawson, R. J., Hall, J. W., Batty, M., & Hutchinson, E. (2019).
Optimising coastal management strategies: Balancing conflicting objectives for an uncertain future.
*Water*, *11*(11), 2319.
https://doi.org/10.3390/w11112319

Specifically, see:
- Table C.3 (p. 33): Model parameters
- Table C.4 (p. 34): Decision lever ranges
- Figure 3 (p. 11): City zone diagram
