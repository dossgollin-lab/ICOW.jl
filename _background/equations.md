# Mathematical Reference: iCOW Model

This document is the definitive mathematical reference for the iCOW (Island City on a Wedge) model.
All equations are from Ceres et al. (2019), with corrections based on the C++ reference implementation.

**C++ Reference:** [rceres/ICOW](https://github.com/rceres/ICOW/blob/master/src/iCOW_2018_06_11.cpp)
(Download locally to `docs/iCOW_2018_06_11.cpp` for reference; cannot be redistributed).

## Decision FloodDefenses (`FloodDefenses` struct)

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

### Physical Cross-Section Diagram

```text
                                         H_city
                                            │
  Sea Level (0) ─────────────────────────────┼─────────────────────────────
       │                                     │
       │   Zone 0: WITHDRAWN                 │
       │   (evacuated, no value)             │
       ├─────────────────────────────────────┤  ← W (withdrawal height)
       │                                     │
       │   Zone 1: RESISTANT                 │
       │   (flood-proofed buildings)         │
       │   Value ratio: r_unprot = 0.95      │
       ├─────────────────────────────────────┤  ← W + min(R, B)
       │                                     │
       │   Zone 2: UNPROTECTED GAP           │    (only if R < B)
       │   (exposed, no resistance)          │
       │   Value ratio: r_unprot = 0.95      │
       ├──────────┬──────────────────────────┤  ← W + B (dike base)
       │   DIKE   │  Zone 3: DIKE PROTECTED  │
       │    ▲     │  (behind dike)           │
       │    │ D   │  Value ratio: r_prot=1.1 │
       │    ▼     │                          │
       ├──────────┴──────────────────────────┤  ← W + B + D (dike top)
       │                                     │
       │   Zone 4: ABOVE DIKE                │
       │   (naturally protected by elevation)│
       │   Value ratio: 1.0                  │
       └─────────────────────────────────────┘  ← H_city
```

### Physical Interpretation of Dike Base (B)

The lever $B$ represents the **elevation of the dike base above the withdrawal zone**.
Physically, this creates a buffer zone between flood-proofed buildings and dike-protected areas.

- If $R < B$: Zone 2 exists as an "unprotected gap" where buildings are neither flood-proofed NOR protected by the dike
- If $R \geq B$: Zone 2 collapses to zero width (no gap)

**Why this matters:** The model allows dike placement at any elevation, not just at the boundary of resistant buildings.
This enables strategies where the dike protects higher-value areas while lower areas rely on flood-proofing.

### Zone Value Ratios (Non-Conservation)

The zone value ratios $r_{prot} = 1.1$ and $r_{unprot} = 0.95$ mean that **zone values do not sum to $V_w$**.
This is intentional and represents:

- **Protected areas appreciate**: Dike protection increases land/building values (capitalization of safety)
- **Unprotected areas depreciate**: Residual flood risk reduces property values

The total value $\sum Val_Z \approx V_w$ but typically differs by a few percent depending on zone allocation.
This models the economic reality that flood protection affects property values, not just damages.

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

### Equation 6: Dike Volume (Corrected)

The paper's original Equation 6 contains a complex polynomial $T$ under a square root that is **numerically unstable** for physically realistic terrain slopes.
The original C++ implementation never actually computed this formula correctly due to an integer division bug.

This implementation uses a **simplified geometric derivation** that is numerically stable and physically correct:

$$
V_{dike} = \underbrace{W_{city} \cdot h_d \left( w_d + \frac{h_d}{s^2} \right)}_{\text{Main Seawall}} + \underbrace{\frac{h_d^2}{S} \left( w_d + \frac{2 h_d}{3 s^2} \right)}_{\text{Side Wings}}
$$

Where:

- $h_d = \mathbf{D} + D_{startup}$ = effective dike height (design height + startup costs)
- $W_{city}$ = length of coastline (43,000 m)
- $w_d$ = width of dike top (3.0 m)
- $s$ = dike side slope parameter (0.5, so horizontal run per unit rise = $1/s^2$ = 4)
- $S = H_{city} / D_{city}$ = city terrain slope (17/2000 = 0.0085)

**Derivation:**

The dike consists of two geometric components:

1. **Main Seawall**: A trapezoidal prism running along the 43 km coastline.
   Cross-sectional area $A = h_d (w_d + h_d/s^2)$, so $V_{main} = W_{city} \cdot A$.

2. **Side Wings**: Two tapered prisms running inland up the city slope.
   At distance $x$ from coast, ground elevation is $S \cdot x$, so local dike height is $h(x) = h_d - S \cdot x$.
   The wing extends from $x=0$ (coast, $h=h_d$) to $x=h_d/S$ (where ground reaches dike height, $h=0$).

   Integrating the cross-section along one wing:

   $$V_{wing} = \int_0^{h_d/S} h(x) \left( w_d + \frac{h(x)}{s^2} \right) dx = \frac{h_d^2}{S} \left( \frac{w_d}{2} + \frac{h_d}{3s^2} \right)$$

   For two wings: $V_{wings} = \frac{h_d^2}{S} \left( w_d + \frac{2h_d}{3s^2} \right)$

**Why the paper's formula fails:**

The paper's $T$ polynomial has $S^4$ in denominators.
With $S = 0.0085$, we get $1/S^4 \approx 1.9 \times 10^8$, causing negative terms to dominate and $T < 0$.
The original C++ avoided this by accidentally computing `pow(T, 0) = 1` instead of `sqrt(T)`.

**Original C++ Bugs (historical documentation):**

The original C++ implementation (iCOW_2018_06_11.cpp) had 8 bugs:

1. **Integer division**: `pow(T, 1/2)` evaluated as `pow(T, 0) = 1` (never computed sqrt)
2. **Array index**: Used constant `dh=5` instead of variable `ch`
3. **Algebraic error**: Wrong coefficient in fourth term of T
4. **Wrong variable**: Used `W` (43000m) instead of `wdt` (3m) in third term
5. **Slope definition**: Used inverted slope ratio
6. **Resistance cost**: Used zone value instead of $V_w$
7. **V_w calculation**: Used $V_{city} - C_W$ instead of Equation 2
8. **Resistance with no dike**: When $B < \text{minHeight}$ (0.1m), C++ sets $R = 0$, preventing "resistance-only" strategies. The correct behavior is to use Equation 4 (unconstrained) when there is no dike ($B = 0$ and $D = 0$), regardless of $R$ value

**Our implementation:**

- Uses simplified geometric formula (numerically stable, physically correct)
- Uses correct terrain slope $S = H_{city}/D_{city} = 0.0085$
- Fixes bugs #6-7 in resistance cost and $V_w$ calculations
- Fixes bug #8: uses Equation 4 (unconstrained) when $B = 0$ and $D = 0$ (no dike), allowing "resistance-only" strategies
- C++ validation (`test/validation/cpp_reference/`) validates cost and zone calculations (dike volume uses different formula)

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

**Physical Interpretation:** The threshold penalty represents **catastrophic damage amplification** - when damages exceed a critical level ($d_{thresh} = V_{city}/375 \approx \$4$ billion by default), additional cascading effects occur:

- **Social disruption**: Essential services fail, supply chains break, businesses close permanently
- **Political costs**: Government instability, delayed recovery, reduced investor confidence
- **Insurance market failures**: Reinsurance capacity exhausted, coverage gaps emerge
- **Compound vulnerabilities**: Damaged infrastructure increases vulnerability to subsequent events

With default parameters ($\gamma_{thresh} = 1.01$), this is nearly linear in excess damage.
Higher $\gamma_{thresh}$ values would model superlinear catastrophic effects.

### Expected Annual Damage (EAD) Integration

The EAD mode integrates event damage over the surge distribution using two-level integration:

$$
\text{EAD} = \mathbb{E}_h\left[\mathbb{E}_{\text{dike}}[\text{damage} \mid h]\right] = \int p_h(h) \cdot \mathbb{E}[\text{damage} \mid h] \, dh
$$

Where the inner expectation (analytical) is:

$$
\mathbb{E}[\text{damage} \mid h] = p_{\text{fail}}(h) \cdot d_{\text{failed}}(h) + (1 - p_{\text{fail}}(h)) \cdot d_{\text{intact}}(h)
$$

And the outer expectation (numerical) integrates over the surge distribution $p_h(h)$.

**Implementation:**

- **Inner expectation** (analytical, exact): `calculate_expected_damage_given_surge(h, city, levers)`
- **Outer expectation** (numerical): Monte Carlo (`calculate_expected_damage_mc`) or adaptive quadrature (`calculate_expected_damage_quad`)

**Key properties:**

- The inner expectation eliminates stochastic dike failure uncertainty analytically
- The outer expectation is computed numerically over the surge distribution
- For static policies, EAD mode converges to the mean of stochastic mode (Law of Large Numbers)

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
| Dike | Cost per volume | $c_d$ | `c_d` | 1000.0 | $/m$^3$ | Construction cost |
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

#### Recalibrated: Dike Unit Cost ($c_d$)

Both the paper and C++ use $c_d = 10$ \$/m$^3$.
However, the C++ `CalculateDikeCost` function has Bug #4 (using `CityWidth` = 43,000 instead of `WidthDikeTop` = 3 in the wing volume term), which inflates dike volume by roughly 100x.
The paper's published results were generated with this bug, so the paper's tradeoff analysis effectively assumes dike costs of $\sim$\$10--20B for a Manhattan-scale seawall.

Our implementation uses the geometrically correct dike volume formula (Equation 6), which produces $\sim$100x less volume for the wing term.
To restore the intended cost scale, we set $c_d = 1000$ \$/m$^3$.
This is also more realistic: $10/m$^3$ covers only raw fill, while $1000/m$^3$ better reflects engineered flood defense construction costs (foundation work, clay core, armor, environmental mitigation).

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

The model uses multiple surge height variables:

1. $h_{raw}$ = raw ocean surge from GEV distribution (absolute elevation)
2. $h_{eff} = h_{raw} \cdot f_{runup} - H_{seawall}$ = effective surge after seawall and runup (absolute elevation from sea level)
3. $h_{at\_dike} = \max(0, h_{eff} - (\mathbf{W} + \mathbf{B}))$ = surge height above dike base

**Critical**: Equation 8 (Dike Failure) uses $h_{surge} = h_{at\_dike}$, the surge height **above the dike base**, not the absolute elevation.
This makes physical sense: dike failure depends on water depth AT the dike, not the absolute surge elevation.

**C++ Reference**: Line 584 of iCOW_2018_06_11.cpp confirms this:
```cpp
double pf = std::max(pfBase, ((sl-cityChar[tz2])/cityChar[dh]-pfThreshold)/(1-pfThreshold));
```
where `sl - cityChar[tz2]` = surge level - dike base = $h_{at\_dike}$.

Zone flooding uses $h_{eff}$ (absolute elevation) compared to zone boundaries.

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
