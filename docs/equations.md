# Mathematical Reference: iCOW Model

This document is the definitive mathematical reference for the iCOW (Island City on a Wedge) model.
All equations are from Ceres et al. (2019), with corrections based on the C++ reference implementation.

**C++ Reference:** [rceres/ICOW](https://github.com/rceres/ICOW/blob/master/src/iCOW_2018_06_11.cpp)
(Download locally to `docs/iCOW_2018_06_11.cpp` for reference; cannot be redistributed).

## Decision Levers (`Levers` struct)

The model has five decision levers (shown in **bold** throughout):

| Lever | Symbol | Field | Description | Units | Constraints |
|-------|--------|-------|-------------|-------|-------------|
| Withdrawal | **W** | `W` | Height below which city is relocated (absolute) | m | $0 \leq W \leq H_{city}$ |
| Resistance Height | **R** | `R` | Height of flood-proofing above $W$ (relative) | m | $R \geq 0$ |
| Resistance Percentage | **P** | `P` | Fraction of buildings made resistant | - | $0 \leq P \leq 1$ |
| Dike Height | **D** | `D` | Height of dike above its base (relative) | m | $D \geq 0$, $W+B+D \leq H_{city}$ |
| Dike Base | **B** | `B` | Height of dike base above $W$ (relative) | m | $B \geq 0$ |

**Coordinate system**: $W$ is the only absolute lever (measured from seawall/sea level).
All other levers ($R$, $B$, $D$) are relative to $W$.
The absolute elevation of the dike base is $W + B$; the dike top is at $W + B + D$.

## Zone Definitions

The city is partitioned into zones based on lever settings (see Figure 3, p. 11):

| Zone | Elevation Range (absolute) | Width (relative) | Description | Value Ratio | Damage Calculation |
|------|---------------------------|------------------|-------------|-------------|---------------------|
| 0 | $0$ to $W$ | $W$ | Withdrawn | 0 | $d_0 = 0$ (no value remains) |
| 1 | $W$ to $W + \min(R, B)$ | $\min(R, B)$ | Resistant | 0.95 | $d_1 = Val_1 \cdot (1-P) \cdot f_{damage}$ |
| 2 | $W + \min(R, B)$ to $W + B$ | $B - R$ (if $R < B$) | Unprotected gap | 0.95 | $d_2 = Val_2 \cdot f_{damage}$ |
| 3 | $W + B$ to $W + B + D$ | $D$ | Dike protected | 1.1 | $d_3 = Val_3 \cdot f_{damage} \cdot f_{dike}$ |
| 4 | $W + B + D$ to $H_{city}$ | $H_{city} - W - B - D$ | Above dike | 1.0 | $d_4 = Val_4 \cdot f_{damage}$ |

Zone 2 only exists if $R < B$ (resistance doesn't reach dike base).
$f_{dike} = f_{intact}$ if dike holds, $f_{failed}$ if dike fails (stochastic per Equation 8).

## Cost Equations

### Equation 1: Withdrawal Cost (p. 14)

$$
C_W = \frac{V_{city} \cdot \mathbf{W} \cdot f_w}{H_{city} - \mathbf{W}}
$$

### Equation 2: City Value After Withdrawal (p. 14)

$$
V_w = V_{city} \cdot \left(1 - \frac{f_l \cdot \mathbf{W}}{H_{city}}\right)
$$

### Equation 3: Resistance Cost Fraction (p. 15)

$$
f_{cR} = f_{adj} \cdot \left( f_{lin} \cdot \mathbf{P} + \frac{f_{exp} \cdot \max(0, \mathbf{P} - t_{exp})}{1 - \mathbf{P}} \right)
$$

Note: $f_{adj} = 1.25$ is in the C++ code but not prominently shown in the paper.

### Equation 4: Resistance Cost - Unconstrained (p. 15)

When $R < B$ or no dike:

$$
C_R = \frac{V_w \cdot f_{cR} \cdot \mathbf{R} \cdot (\mathbf{R}/2 + b)}{H_{bldg} \cdot (H_{city} - \mathbf{W})}
$$

### Equation 5: Resistance Cost - Constrained (p. 16)

When $R \geq B$ (resistance capped at dike base):

$$
C_R = \frac{V_w \cdot f_{cR} \cdot \mathbf{B} \cdot (\mathbf{R} - \mathbf{B}/2 + b)}{H_{bldg} \cdot (H_{city} - \mathbf{W})}
$$

Note: $R > B$ is a **dominated strategy** - physical protection is capped at $B$ but cost increases with $R$.

### Equation 6: Dike Volume (p. 17)

$$
V_d = W_{city} \cdot h_d \left( w_d + \frac{h_d}{s^2} \right) + \frac{1}{6} \sqrt{T} + w_d \frac{h_d^2}{S^2}
$$

Where the term under the square root is:

$$
T = -\frac{h_d^4 (h_d + 1/s)^2}{s^2} - \frac{2h_d^5(h_d + 1/s)}{S^4} - \frac{4h_d^6}{s^2 S^4} + \frac{4h_d^4(2h_d(h_d + 1/s) - 3h_d^2/s^2)}{s^2 S^2} + \frac{2h_d^3(h_d + 1/s)}{S^2}
$$

And $h_d = \mathbf{D} + D_{startup}$ (total effective dike height including startup costs).

**WARNING**: The C++ code has a bug where `dh=5` (an index constant) is used instead of `ch` (cost height).
Use the paper formula.

### Equation 7: Dike Cost (p. 17)

$$
C_D = V_d \cdot c_d
$$

### Total Investment Cost

$$
C_{total} = C_W + C_R + C_D
$$

## Damage Equations

### Effective Surge Height (from C++ code)

$$
h_{eff} = \begin{cases}
0 & \text{if } h_{raw} \leq H_{seawall} \\
h_{raw} \cdot f_{runup} - H_{seawall} & \text{if } h_{raw} > H_{seawall}
\end{cases}
$$

### Equation 8: Dike Failure Probability (p. 17)

The paper formula is dimensionally inconsistent.
Use the corrected piecewise form:

$$
p_{fail} = \begin{cases}
p_{min} & \text{if } h_{surge} < t_{fail} \cdot \mathbf{D} \\
\frac{h_{surge} - t_{fail} \cdot \mathbf{D}}{\mathbf{D}(1 - t_{fail})} & \text{if } t_{fail} \cdot \mathbf{D} \leq h_{surge} < \mathbf{D} \\
1.0 & \text{if } h_{surge} \geq \mathbf{D}
\end{cases}
$$

### Equation 9: Damage by Zone (p. 18)

$$
d_Z = Val_Z \cdot \frac{Vol_F}{Vol_Z} \cdot f_{damage}
$$

### Zone Value Calculations (from C++ code)

$$
Val_{Z1} = V_w \cdot r_{unprot} \cdot \frac{\min(\mathbf{R}, \mathbf{B})}{H_{city} - \mathbf{W}}
$$

$$
Val_{Z2} = V_w \cdot r_{unprot} \cdot \frac{\mathbf{B} - \mathbf{R}}{H_{city} - \mathbf{W}}
$$

$$
Val_{Z3} = V_w \cdot r_{prot} \cdot \frac{\mathbf{D}}{H_{city} - \mathbf{W}}
$$

$$
Val_{Z4} = V_w \cdot \frac{H_{city} - \mathbf{W} - \mathbf{B} - \mathbf{D}}{H_{city} - \mathbf{W}}
$$

### Protected Zone Damage (from C++ code)

$$
d_{Z3} = \begin{cases}
Val_{Z3} \cdot f_{damage} \cdot f_{intact} \cdot (\text{flood fraction}) & \text{if dike intact} \\
Val_{Z3} \cdot f_{damage} \cdot f_{failed} \cdot (\text{flood fraction}) & \text{if dike failed}
\end{cases}
$$

### Threshold Damage (from C++ code)

$$
d_{total} = \begin{cases}
\sum d_Z & \text{if } \sum d_Z \leq d_{thresh} \\
\sum d_Z + \left( f_{thresh} \cdot (\sum d_Z - d_{thresh}) \right)^{\gamma_{thresh}} & \text{if } \sum d_Z > d_{thresh}
\end{cases}
$$

## Parameters (`CityParameters` struct)

All exogenous parameters are fields in the `CityParameters` struct.

| Category | Parameter | Symbol | Field | Default | Units | Description |
|----------|-----------|--------|-------|---------|-------|-------------|
| Geometry | Initial city value | $V_{city}$ | `V_city` | $1.5 \times 10^{12}$ | $ | Total infrastructure value |
| Geometry | Building height | $H_{bldg}$ | `H_bldg` | 30.0 | m | Representative building height |
| Geometry | City max elevation | $H_{city}$ | `H_city` | 17.0 | m | Elevation change across city |
| Geometry | City depth | $D_{city}$ | `D_city` | 2000.0 | m | Distance from seawall to peak |
| Geometry | City length | $W_{city}$ | `W_city` | 43000.0 | m | Length of seawall coastline |
| Geometry | Seawall height | $H_{seawall}$ | `H_seawall` | 1.75 | m | Existing seawall protection |
| Dike | Startup height | $D_{startup}$ | `D_startup` | 2.0 | m | Equivalent height for fixed costs |
| Dike | Top width | $w_d$ | `w_d` | 3.0 | m | Width of dike top |
| Dike | Side slope | $s$ | `s_dike` | 0.5 | m/m | Horizontal/vertical ratio |
| Dike | Cost per volume | $c_d$ | `c_d` | 10.0 | $/m$^3$ | Material cost |
| Zones | Protected ratio | $r_{prot}$ | `r_prot` | 1.1 | - | Value multiplier for zone 3 |
| Zones | Unprotected ratio | $r_{unprot}$ | `r_unprot` | 0.95 | - | Value multiplier for zones 1-2 |
| Withdrawal | Cost factor | $f_w$ | `f_w` | 1.0 | - | Withdrawal cost adjustment |
| Withdrawal | Loss fraction | $f_l$ | `f_l` | 0.01 | - | Fraction that leaves vs relocates |
| Resistance | Adjustment factor | $f_{adj}$ | `f_adj` | 1.25 | - | Overall cost multiplier |
| Resistance | Linear factor | $f_{lin}$ | `f_lin` | 0.35 | - | Linear cost component |
| Resistance | Exponential factor | $f_{exp}$ | `f_exp` | 0.115 | - | Exponential cost component |
| Resistance | Exp threshold | $t_{exp}$ | `t_exp` | 0.4 | - | Threshold for exponential costs |
| Resistance | Basement depth | $b$ | `b_basement` | 3.0 | m | Representative basement depth |
| Damage | Damage fraction | $f_{damage}$ | `f_damage` | 0.39 | - | Fraction of value lost per flood |
| Damage | Intact dike factor | $f_{intact}$ | `f_intact` | 0.03 | - | Damage when dike holds |
| Damage | Failed dike factor | $f_{failed}$ | `f_failed` | 1.5 | - | Damage when dike fails |
| Damage | Failure threshold | $t_{fail}$ | `t_fail` | 0.95 | - | Surge/height ratio for failure |
| Damage | Min failure prob | $p_{min}$ | `p_min` | 0.05 | - | Base failure probability |
| Damage | Wave runup factor | $f_{runup}$ | `f_runup` | 1.1 | - | Surge amplification |
| Threshold | Damage threshold | $d_{thresh}$ | `d_thresh` | V_city/375 | $ | "Unacceptable" damage level |
| Threshold | Threshold fraction | $f_{thresh}$ | `f_thresh` | 1.0 | - | Excess damage multiplier |
| Threshold | Threshold exponent | $\gamma_{thresh}$ | `gamma_thresh` | 1.01 | - | Excess damage exponent |

**Note**: City slope $S = H_{city} / D_{city}$ is computed, not stored.
The C++ code incorrectly calculates slope as `CityLength/CityWidth`.

## Intermediate Variables

These are computed values, not struct fields:

| Variable | Symbol | Field | Computed From | Description |
|----------|--------|-------|---------------|-------------|
| City slope | $S$ | `S` | `H_city / D_city` | Elevation gradient |
| Value after withdrawal | $V_w$ | `V_w` | Equation 2 | Remaining city value |
| Resistance cost fraction | $f_{cR}$ | `f_cR` | Equation 3 | Unitless multiplier |
| Effective dike height | $h_d$ | `h_d` | `D + D_startup` | For Equation 6 |
| Dike volume | $V_d$ | `V_d` | Equation 6 | Cubic meters |
| Effective surge | $h_{eff}$ | `h_eff` | See above | Adjusted surge height |
| Dike failure probability | $p_{fail}$ | `p_fail` | Equation 8 | Per-event probability |

## Implementation Guidance

### Paper vs C++ Code Discrepancies

The paper and C++ reference implementation have discrepancies.
Follow these rules:

#### Trust the C++ Code for Parameters

These values differ from Table 3/4 in the paper:

| Parameter | Paper Value | C++ Value (USE THIS) |
|-----------|-------------|----------------------|
| $f_{exp}$ | 0.9 | 0.115 |
| $t_{exp}$ | 0.6 | 0.4 |
| $f_{failed}$ | 1.3 | 1.5 |
| $p_{min}$ | 0.001 | 0.05 |
| $D_{startup}$ | 3.0 | 2.0 |
| $w_d$ | 4.0 | 3.0 |

#### Trust the C++ Code for Logic

- Equation 8 (dike failure): Use corrected piecewise form
- Damage calculations: Use intact/failed dike factors
- Effective surge: Use $h_{eff} = h_{raw} \cdot f_{runup} - H_{seawall}$

#### Trust the Paper for Geometry

- Equation 6 (dike volume): Use paper formula - C++ has bug with `dh=5`
- City slope: Use $S = H_{city}/D_{city}$ - C++ incorrectly uses length/width

#### Hidden Factors in C++ Code

These are implemented but not prominently documented in the paper:

- $f_{adj} = 1.25$ multiplies entire resistance cost fraction
- $f_{runup} = 1.1$ multiplies surge before subtracting seawall
- $r_{prot} = 1.1$ and $r_{unprot} = 0.95$ adjust zone values
- $f_{intact} = 0.03$ reduces damage when dike holds

## Implementation Clarifications

### Zone 2 Division by Zero

When $R \geq B$, Zone 2 has zero width ($B - R \leq 0$).
In this case, $Val_{Z2} = 0$ and $d_2 = 0$.
**Implementation**: Skip Zone 2 entirely when $R \geq B$ to avoid division by zero in volume calculations.

### Surge Height Variables

Equation 8 (Dike Failure) uses $h_{surge}$.
This refers to **effective surge** $h_{eff}$, not raw ocean surge $h_{raw}$.

The chain is:

1. $h_{raw}$ = raw ocean surge from GEV distribution
2. $h_{eff} = h_{raw} \cdot f_{runup} - H_{seawall}$ (if $h_{raw} > H_{seawall}$, else 0)
3. $h_{surge} = h_{eff}$ in Equation 8 and all damage calculations

### Cost vs Damage Integration

**Costs** ($C_W$, $C_R$, $C_D$) are one-time investments computed from lever settings.

**Damages** ($d_Z$) are computed per surge event.
The simulation uses **Monte Carlo**: for each year $t$ and scenario $s$, sample whether the dike fails (Bernoulli with $p_{fail}$), then sum damages across zones.

**Total objective** over simulation horizon $T$:
$$
\text{Objective} = C_{total} + \sum_{t=1}^{T} \sum_{s} d_{total}(t, s) \cdot \delta^t
$$

Where $\delta$ is the discount factor (default 1.0 for 0% discounting per C++ reference).

## Notes

1. **Units**: All monetary values are in raw dollars (not scaled).
   $V_{city} = 1.5 \times 10^{12}$ means $1.5 trillion.

2. **Dominated strategies**: $R > B$ is dominated (costs more, provides no additional protection).

3. **Stochastic elements**: Dike failure (Eq 8) introduces stochasticity into damage calculations.
