# Parameter Reference

This document describes all parameters in the iCOW model.

## CityParameters

The `CityParameters{T}` struct contains 27 exogenous parameters organized into seven categories.
All monetary values are in raw dollars (not scaled).
Heights are in meters.

### Quick Reference

| Category | Count | Fields |
| -------- | ----- | ------ |
| Geometry | 6 | V_city, H_bldg, H_city, D_city, W_city, H_seawall |
| Dike | 4 | D_startup, w_d, s_dike, c_d |
| Zones | 2 | r_prot, r_unprot |
| Withdrawal | 2 | f_w, f_l |
| Resistance | 5 | f_adj, f_lin, f_exp, t_exp, b_basement |
| Damage | 6 | f_damage, f_intact, f_failed, t_fail, p_min, f_runup |
| Threshold | 3 | d_thresh, f_thresh, gamma_thresh |

### Geometry Parameters

| Symbol | Field | Default | Units | Description |
| ------ | ----- | ------- | ----- | ----------- |
| $V_{city}$ | `V_city` | $1.5 \times 10^{12}$ | $ | Total infrastructure value |
| $H_{bldg}$ | `H_bldg` | 30.0 | m | Representative building height |
| $H_{city}$ | `H_city` | 17.0 | m | Elevation change across city (seawall to peak) |
| $D_{city}$ | `D_city` | 2000.0 | m | Distance from seawall to peak |
| $W_{city}$ | `W_city` | 43000.0 | m | Length of seawall coastline |
| $H_{seawall}$ | `H_seawall` | 1.75 | m | Existing seawall protection height |

The city slope $S = H_{city} / D_{city}$ is computed via `city_slope(city)`.

### Dike Parameters

| Symbol | Field | Default | Units | Description |
| ------ | ----- | ------- | ----- | ----------- |
| $D_{startup}$ | `D_startup` | 2.0 | m | Equivalent height for fixed mobilization costs |
| $w_d$ | `w_d` | 3.0 | m | Width of dike top |
| $s$ | `s_dike` | 0.5 | - | Dike side slope (horizontal/vertical) |
| $c_d$ | `c_d` | 10.0 | $/m$^3$ | Material cost per unit volume |

### Zone Parameters

| Symbol | Field | Default | Units | Description |
| ------ | ----- | ------- | ----- | ----------- |
| $r_{prot}$ | `r_prot` | 1.1 | - | Value multiplier for dike-protected zone |
| $r_{unprot}$ | `r_unprot` | 0.95 | - | Value multiplier for unprotected zones |

### Withdrawal Parameters

| Symbol | Field | Default | Units | Description |
| ------ | ----- | ------- | ----- | ----------- |
| $f_w$ | `f_w` | 1.0 | - | Withdrawal cost adjustment factor |
| $f_l$ | `f_l` | 0.01 | - | Fraction of value that leaves (vs relocates) |

### Resistance Parameters

| Symbol | Field | Default | Units | Description |
| ------ | ----- | ------- | ----- | ----------- |
| $f_{adj}$ | `f_adj` | 1.25 | - | Overall cost multiplier (hidden in C++ code) |
| $f_{lin}$ | `f_lin` | 0.35 | - | Linear component of cost function |
| $f_{exp}$ | `f_exp` | 0.115 | - | Exponential component of cost function |
| $t_{exp}$ | `t_exp` | 0.4 | - | Threshold for exponential cost activation |
| $b$ | `b_basement` | 3.0 | m | Representative basement depth |

### Damage Parameters

| Symbol | Field | Default | Units | Description |
| ------ | ----- | ------- | ----- | ----------- |
| $f_{damage}$ | `f_damage` | 0.39 | - | Fraction of zone value lost when flooded |
| $f_{intact}$ | `f_intact` | 0.03 | - | Damage reduction when dike holds |
| $f_{failed}$ | `f_failed` | 1.5 | - | Damage amplification when dike fails |
| $t_{fail}$ | `t_fail` | 0.95 | - | Surge/height ratio where failure probability rises |
| $p_{min}$ | `p_min` | 0.05 | - | Baseline dike failure probability |
| $f_{runup}$ | `f_runup` | 1.1 | - | Wave runup amplification factor |

### Threshold Parameters

| Symbol | Field | Default | Units | Description |
| ------ | ----- | ------- | ----- | ----------- |
| $d_{thresh}$ | `d_thresh` | $V_{city}/375$ | $ | Damage level triggering catastrophic effects |
| $f_{thresh}$ | `f_thresh` | 1.0 | - | Excess damage multiplier |
| $\gamma_{thresh}$ | `gamma_thresh` | 1.01 | - | Excess damage exponent |

## Levers

The `Levers{T}` struct contains 5 decision variables.

| Symbol | Field | Units | Constraints | Description |
| ------ | ----- | ----- | ----------- | ----------- |
| $W$ | `W` | m | $W \geq 0$ | Withdrawal height (absolute elevation) |
| $R$ | `R` | m | $R \geq 0$ | Resistance height above $W$ (relative) |
| $P$ | `P` | - | $0 \leq P < 1$ | Fraction of buildings made resistant |
| $D$ | `D` | m | $D \geq 0$ | Dike height above base (relative) |
| $B$ | `B` | m | $B \geq 0$ | Dike base height above $W$ (relative) |

### Coordinate System

$W$ is the only absolute lever (measured from seawall/sea level).
All other levers ($R$, $B$, $D$) are relative to $W$.

- Dike base elevation: $W + B$
- Dike top elevation: $W + B + D$

### City-Dependent Constraints

The function `is_feasible(levers, city)` checks:

- $W \leq H_{city}$ (cannot withdraw above city peak)
- $W + B + D \leq H_{city}$ (dike cannot exceed city elevation)

### Critical Constraint

$P$ must be strictly less than 1.0 because Equation 3 contains the term $1/(1-P)$.
Setting $P = 1.0$ causes division by zero.

## Paper vs C++ Discrepancies

Several defaults differ between the paper and C++ implementation.
This package uses the C++ values:

| Parameter | Paper Value | C++ Value (used) |
| --------- | ----------- | ---------------- |
| $f_{exp}$ | 0.9 | 0.115 |
| $t_{exp}$ | 0.6 | 0.4 |
| $f_{failed}$ | 1.3 | 1.5 |
| $p_{min}$ | 0.001 | 0.05 |
| $D_{startup}$ | 3.0 | 2.0 |
| $w_d$ | 4.0 | 3.0 |

The city slope formula uses $S = H_{city}/D_{city}$ from the paper, NOT the buggy C++ formula.
