# Mathematical Equations for iCOW Model

This document contains all mathematical equations from Ceres et al. (2019), transcribed in LaTeX format.
Each equation includes the original equation number, page reference, and complete symbol definitions.

**IMPORTANT:** This document is pending user review and approval before implementation.

## Equation 1: Withdrawal Cost (p. 14)

**Source:** Ceres et al. (2019), Section 2.4.1, page 14

$$
C_W(W) = \frac{v_i \times W \times f_w}{H_{city} - W}
$$

### Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $C_W$ | Cost of withdrawal | $ |
| $W$ | Withdrawal height (height below which city is relocated) | m |
| $v_i$ | Initial city value | $ |
| $f_w$ | Withdrawal adjustment factor | dimensionless |
| $H_{city}$ | Maximum city height | m |

### Physical Interpretation

Cost to relocate infrastructure from elevations below W to higher elevations.
Cost increases as W approaches $H_{city}$ because less space is available for relocation.

## Equation 2: City Value After Withdrawal (p. 14)

**Source:** Ceres et al. (2019), Section 2.4.1, page 14

$$
v_w = v_i \times \left(1 - \frac{f_l \times W}{H_{city}}\right)
$$

### Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $v_w$ | City value after withdrawal | $ |
| $v_i$ | Initial city value | $ |
| $f_l$ | Fraction that leaves vs relocates | dimensionless |
| $W$ | Withdrawal height | m |
| $H_{city}$ | Maximum city height | m |

### Physical Interpretation

Some fraction ($f_l$) of displaced infrastructure leaves the city entirely rather than relocating to higher ground, reducing total city value.

## Equation 3: Resistance Cost Fraction (p. 15)

**Source:** Ceres et al. (2019), Section 2.4.2, page 15

$$
f_{cR}(P) = f_{lin} \times P + \frac{f_{exp} \times \max(0, P - t_{exp})}{1 - P}
$$

### Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $f_{cR}$ | Resistance cost fraction (per unit value) | dimensionless |
| $P$ | Percentage of resistance (0 to 1) | dimensionless |
| $f_{lin}$ | Linear cost factor | dimensionless |
| $f_{exp}$ | Exponential cost factor | dimensionless |
| $t_{exp}$ | Threshold for exponential costs | dimensionless |

### Physical Interpretation

Cost per unit value to implement resistance level P.
Linear at low P, exponential as P approaches 1 (complete protection is infinitely expensive).

## Equation 4: Resistance Cost (Unconstrained) (p. 15)

**Source:** Ceres et al. (2019), Section 2.4.2, page 15

When resistance is NOT constrained by a dike (R < B or no dike):

$$
C_R = \frac{v_w \times f_{cR}(P) \times R \times (R/2 + b)}{h \times (H_{city} - W)}
$$

### Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $C_R$ | Total resistance cost | $ |
| $v_w$ | City value after withdrawal | $ |
| $f_{cR}(P)$ | Resistance cost fraction | dimensionless |
| $R$ | Resistance height | m |
| $P$ | Resistance percentage | dimensionless |
| $b$ | Basement depth | m |
| $h$ | Building height | m |
| $W$ | Withdrawal height | m |
| $H_{city}$ | Maximum city height | m |

### Physical Interpretation

Cost to flood-proof buildings in the resistance zone (from W to W+R).
Includes basement protection costs.

## Equation 5: Resistance Cost (Constrained by Dike) (p. 16)

**Source:** Ceres et al. (2019), Section 2.4.2, page 16

When resistance IS constrained by dike base (R ≥ B):

$$
C_R = \frac{v_w \times f_{cR}(P) \times B \times (R - B/2 + b)}{h \times (H_{city} - W)}
$$

### Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $C_R$ | Total resistance cost | $ |
| $v_w$ | City value after withdrawal | $ |
| $f_{cR}(P)$ | Resistance cost fraction | dimensionless |
| $B$ | Dike base elevation above seawall | m |
| $R$ | Resistance height | m |
| $P$ | Resistance percentage | dimensionless |
| $b$ | Basement depth | m |
| $h$ | Building height | m |
| $W$ | Withdrawal height | m |
| $H_{city}$ | Maximum city height | m |

### Physical Interpretation

When dike exists, resistance only applied from W to B (dike base).
The area behind the dike (zone 3) is protected by the dike, not by building-level resistance.

## Equation 6: Dike Volume (p. 17)

**Source:** Ceres et al. (2019), Section 2.4.3, page 17

The volume of a U-shaped dike on a wedge geometry is:

$$
V_d = W_{city} h \left( w_d + \frac{h}{s^2} \right) + \frac{1}{6} \sqrt{-\frac{h^4 (h + \frac{1}{s})^2}{s^2} - \frac{2h^5(h + \frac{1}{s})}{S^4} - \frac{4h^6}{s^2 S^4} + \frac{4h^4(2h(h + \frac{1}{s}) - \frac{4h^2}{s^2} + \frac{h^2}{s^2})}{s^2 S^2} + \frac{2h^3(h + \frac{1}{s})}{S^2}} + w_d \frac{h^2}{S^2}
$$

### Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $V_d$ | Total volume of dike material | m³ |
| $h$ | Total effective dike height ($h = D + D_{startup}$) | m |
| $D$ | Dike height above base elevation | m |
| $D_{startup}$ | Equivalent startup height (accounts for fixed costs) | m |
| $W_{city}$ | Width of city along seawall (city length) | m |
| $w_d$ | Width of dike top | m |
| $s$ | Side slope of dike (horizontal/vertical ratio) | m/m |
| $S$ | Slope of city wedge ($S = H_{city} / D_{city}$) | m/m |

### Physical Interpretation

Volume of earthen material needed to construct a U-shaped dike on a sloped wedge-shaped city.
Three main components:

1. Main rectangular section parallel to seawall
2. Wing correction for irregular tetrahedron volumes on sloped sides (square root term)
3. Top-width correction for maintaining constant width on sloped terrain

The startup height $D_{startup}$ represents fixed costs as equivalent additional height.

## Equation 7: Dike Cost (p. 17)

**Source:** Ceres et al. (2019), Section 2.4.3, page 17

$$
C_D = V_d \times c_{dpv}
$$

### Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $C_D$ | Total dike cost | $ |
| $V_d$ | Dike volume (from Equation 6) | m³ |
| $c_{dpv}$ | Cost per cubic meter of dike material | $/m³ |

### Physical Interpretation

Cost is directly proportional to dike volume.
Startup costs are embedded in volume calculation through $D_{startup}$.

## Equation 8: Dike Failure Probability (p. 17)

**Source:** Ceres et al. (2019), Section 2.4.3, page 17

$$
P_f(h_{surge}) = \begin{cases}
P_{min} & \text{if } h_{surge} < t_{df} \times D \\
\frac{h_{surge} - t_{df} \times D}{D - t_{df} \times D} & \text{if } t_{df} \times D \leq h_{surge} < D \\
1.0 & \text{if } h_{surge} \geq D
\end{cases}
$$

### Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $P_f$ | Probability of dike failure | dimensionless (0-1) |
| $h_{surge}$ | Surge height above dike base | m |
| $D$ | Dike height | m |
| $t_{df}$ | Dike failure threshold (default 0.95) | dimensionless |
| $P_{min}$ | Minimum failure probability (e.g., 0.001) | dimensionless |

### Physical Interpretation

Dikes have three failure regimes:

1. Below threshold: Low constant failure probability (improper maintenance, etc.)
2. Threshold to design height: Linearly increasing failure probability
3. Overtopping: Certain failure (P = 1.0)

## Equation 9: Damage by Zone (p. 18)

**Source:** Ceres et al. (2019), Section 2.4.4, page 18

Damage to each zone z is:

$$
D_z = V_{alue}(z) \times \frac{V_{olume\_flooded}(z)}{V_{olume\_total}(z)} \times f_{damage}
$$

### Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $D_z$ | Damage in zone z | $ |
| $V_{alue}(z)$ | Total value in zone z | $ |
| $V_{olume\_flooded}(z)$ | Volume flooded in zone z | m³ |
| $V_{olume\_total}(z)$ | Total volume in zone z | m³ |
| $f_{damage}$ | Damage fraction (fraction of value lost per unit flooding) | dimensionless |

### Physical Interpretation

Zone-by-zone damage calculation based on:

- Fraction of zone that is flooded
- Value density in that zone
- Base damage fraction

Modified by:

- Resistance percentage P in zone 1 (reduces damage)
- Dike failure in zone 3 (increased damage if failed)
- Basement flooding (discrete damage when water reaches building base)

Zones are defined in Figure 3 of the paper (see docs/zones.md).

## Implementation Notes

**IMPORTANT:** All equations must be implemented EXACTLY as written.
Do not simplify or approximate any terms.

Equation 6 (Dike Volume) is particularly complex and must be implemented with care.
The square root argument should be non-negative for physical solutions.

**AWAITING USER REVIEW AND APPROVAL BEFORE IMPLEMENTATION**
