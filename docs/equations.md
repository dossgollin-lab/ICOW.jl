# Mathematical Equations for iCOW Model

This document contains all mathematical equations from Ceres et al. (2019), transcribed as they appear in the original paper.
Each equation includes the original equation number and page reference.

## Equations

Equation 1: Withdrawal Cost (p. 14):

$$
C_w = \frac{v_i * \mathbf{W} * f_w}{\text{city height} - \mathbf{W}}
$$

Equation 2: City Value After Withdrawal (p. 14)

$$
v_w = v_i * \left(1 - \frac{f_l * \mathbf{W}}{\text{city height}}\right)
$$

Equation 3: Resistance Cost Fraction (p. 15)

$$
f_{c_R} = f_{adj} * \left( f_{lin} * \mathbf{P} + \frac{f_{exp} * \max(0, \mathbf{P} - t_{exp})}{(1 - \mathbf{P})} \right)
$$

Note: The C++ code includes a resistance adjustment factor $f_{adj} = 1.25$ that multiplies the entire expression. This is not shown in the paper but is present in the reference implementation.

Equation 4: Resistance Cost (Unconstrained) (p. 15)

When resistance is NOT constrained by a dike ($\mathbf{R} < \mathbf{B}$ or no dike):

$$
c_R = \frac{v_w * f_{c_R} * \mathbf{R} * (\mathbf{R}/2 + b)}{h * (\text{city elevation} - \mathbf{W})}
$$

Equation 5: Resistance Cost (Constrained by Dike) (p. 16)

When resistance IS constrained by dike base ($\mathbf{R} \geq \mathbf{B}$):

$$
c_R = \frac{v_w * f_{c_R} * \mathbf{B} * (\mathbf{R} - \mathbf{B}/2 + b)}{h * (\text{city elevation} - \mathbf{W})}
$$

Note: $\mathbf{R} > \mathbf{B}$ is a **dominated strategy**.
The physical protection is capped at $\mathbf{B}$, but cost increases with $\mathbf{R}$.
A rational optimizer should constrain $\mathbf{R} \leq \mathbf{B}$ when a dike exists.

Equation 6: Dike Volume (p. 17)

$$
V_d = W_{city} h \left( w_d + \frac{h}{s^2} \right) + \frac{1}{6} \left[ -\frac{h^4 \left(h + \frac{1}{s}\right)^2}{s^2} - \frac{2h^5 \left(h + \frac{1}{s}\right)}{S^4} - \frac{4h^6}{s^2 S^4} + \frac{4h^4 \left( 2h \left(h + \frac{1}{s}\right) - \frac{4h^2}{s^2} + \frac{h^2}{s^2} \right)}{s^2 S^2} + \frac{2h^3 \left(h + \frac{1}{s}\right)}{S^2} \right]^{\frac{1}{2}} + w_d \frac{h^2}{S^2}
$$

Equation 7: Dike Cost (p. 17)

$$
c_D = V_d * c_{dpv}
$$

Equation 8: Dike Failure Probability (p. 17)

As written in the paper:

$$
p_{df} = \frac{h_{surge} - t_{df}}{\mathbf{D} - t_{df}}
$$

This formula is dimensionally inconsistent ($h_{surge}$ and $\mathbf{D}$ are in meters, $t_{df}$ is dimensionless).
The corrected implementation multiplies $t_{df}$ by $\mathbf{D}$ to convert the threshold fraction to meters, and uses piecewise clamping:

$$
p_{df} = \begin{cases}
P_{min} & \text{if } h_{surge} < t_{df} * \mathbf{D} \\
\frac{h_{surge} - t_{df} * \mathbf{D}}{\mathbf{D} - t_{df} * \mathbf{D}} & \text{if } t_{df} * \mathbf{D} \leq h_{surge} < \mathbf{D} \\
1.0 & \text{if } h_{surge} \geq \mathbf{D}
\end{cases}
$$

Equation 9: Damage by Zone (p. 18)

$$
d_Z = Val_Z * \frac{Vol_F}{Vol_Z} * f_{damage}
$$

## Additional Model Components (from C++ implementation)

The following equations are not explicitly numbered in the paper but are implemented in the reference C++ code.

### Effective Surge Height

The effective surge affecting the city accounts for seawall protection and wave runup:

$$
h_{eff} = \begin{cases}
0 & \text{if } h_{raw} \leq H_{seawall} \\
h_{raw} * f_{runup} - H_{seawall} & \text{if } h_{raw} > H_{seawall}
\end{cases}
$$

Where $h_{raw}$ is the raw storm surge height, $H_{seawall}$ is the seawall height, and $f_{runup}$ is the wave runup multiplier.

### Zone Value Calculations

Zone values are calculated with value ratios that depend on protection status:

$$
Val_{Z1} = v_w * r_{unprot} * \frac{\min(\mathbf{R}, \mathbf{B})}{H_{city} - \mathbf{W}}
$$

$$
Val_{Z3} = v_w * r_{prot} * \frac{\mathbf{D}}{H_{city} - \mathbf{W}}
$$

Where $r_{unprot}$ is the unprotected value ratio (zones 1-2) and $r_{prot}$ is the protected value ratio (zone 3, behind dike).

### Damage Multipliers for Protected Zone

Damage in the protected zone (zone 3) depends on whether the dike fails:

$$
d_{Z3} = \begin{cases}
Val_{Z3} * f_{damage} * f_{intact} * (\text{flood fraction}) & \text{if dike intact} \\
Val_{Z3} * f_{damage} * f_{failed} * (\text{flood fraction}) & \text{if dike failed}
\end{cases}
$$

Where $f_{intact}$ is the intact dike damage factor and $f_{failed}$ is the failed dike damage factor.

### Threshold Damage

When total damage exceeds a threshold level, additional "unacceptable" damage is added:

$$
d_{total} = \begin{cases}
\sum d_Z & \text{if } \sum d_Z \leq d_{thresh} \\
\sum d_Z + \left( f_{thresh} * (\sum d_Z - d_{thresh}) \right)^{\gamma_{thresh}} & \text{if } \sum d_Z > d_{thresh}
\end{cases}
$$

Where $d_{thresh} = v_i / 375$ is the damage threshold level.

## Symbol Definitions

| Symbol | Definition | Units |
|--------|------------|-------|
| $\mathbf{W}$ | Withdrawal height (height from seawall below which city is relocated) | m |
| $\mathbf{R}$ | Resistance height | m |
| $\mathbf{P}$ | Percentage of resistance (0 to 1) | dimensionless |
| $\mathbf{D}$ | Dike height above base elevation | m |
| $\mathbf{B}$ | Dike base elevation above seawall | m |
| $C_w$ | Cost of withdrawal | $ |
| $c_R$ | Total resistance cost | $ |
| $c_D$ | Total dike cost | $ |
| $v_i$ | Initial city value (see note 1) | \$T |
| $v_w$ | City value after withdrawal | $ |
| $\text{city height}$ | Maximum city height | m |
| $\text{city elevation}$ | Maximum city elevation (same as city height) | m |
| $W_{city}$ | Width of city along seawall (city length) | m |
| $h$ | Building height (Eqs. 4-5) OR total effective dike height $h = D + D_{startup}$ (Eq. 6) | m |
| $b$ | Basement depth | m |
| $f_w$ | Withdrawal adjustment factor | dimensionless |
| $f_l$ | Fraction that leaves vs relocates | dimensionless |
| $f_{c_R}$ | Resistance cost fraction (per unit value) | dimensionless |
| $f_{lin}$ | Linear cost factor | dimensionless |
| $f_{exp}$ | Exponential cost factor | dimensionless |
| $t_{exp}$ | Threshold for exponential resistance costs (default 0.6) | dimensionless |
| $f_{damage}$ | Damage fraction (fraction of value lost per unit flooding) | dimensionless |
| $V_d$ | Total volume of dike material | m³ |
| $w_d$ | Width of dike top | m |
| $s$ | Side slope of dike (horizontal/vertical ratio) | m/m |
| $S$ | Slope of city wedge ($S = H_{city} / D_{city}$) | m/m |
| $D_{startup}$ | Equivalent startup height (accounts for fixed costs) | m |
| $c_{dpv}$ | Cost per cubic meter of dike material | $/m³ |
| $p_{df}$ | Probability of dike failure | dimensionless |
| $h_{surge}$ | Surge height above dike base | m |
| $t_{df}$ | Dike failure threshold (default 0.95) | dimensionless |
| $P_{min}$ | Minimum failure probability | dimensionless |
| $d_Z$ | Damage in zone Z | $ |
| $Val_Z$ | Total value in zone Z | $ |
| $Vol_F$ | Volume flooded in zone Z | m$^3$ |
| $Vol_Z$ | Total volume in zone Z | m$^3$ |
| $f_{adj}$ | Resistance adjustment factor (default 1.25) | dimensionless |
| $H_{seawall}$ | Seawall height (default 1.75) | m |
| $f_{runup}$ | Wave runup multiplier (default 1.1) | dimensionless |
| $h_{raw}$ | Raw storm surge height (before seawall/runup adjustment) | m |
| $h_{eff}$ | Effective surge height affecting city | m |
| $r_{prot}$ | Protected value ratio (zone 3, default 1.1) | dimensionless |
| $r_{unprot}$ | Unprotected value ratio (zones 1-2, default 0.95) | dimensionless |
| $f_{intact}$ | Intact dike damage factor (default 0.03) | dimensionless |
| $f_{failed}$ | Failed dike damage factor (default 1.5) | dimensionless |
| $d_{thresh}$ | Damage threshold for "unacceptable" damage ($v_i / 375$) | \$ |
| $f_{thresh}$ | Threshold damage fraction (default 1.0) | dimensionless |
| $\gamma_{thresh}$ | Threshold damage exponent (default 1.01) | dimensionless |

## Notes

1. **Units**: $v_i$ is in \$T (trillions of dollars). Default value 1.5 means \$1.5 trillion = \$1,500,000,000,000.

2. **Symbol $h$ is overloaded**: Building height in Equations 4-5, but total effective dike height ($h = \mathbf{D} + D_{startup}$) in Equation 6. Note: Table 3 in the paper uses "B = 30 m" for building height, which corresponds to $h$ in the equations — not the decision lever $\mathbf{B}$ (dike base elevation).

3. **Notation**: The paper uses lowercase $d_Z$ for damage and uppercase $\mathbf{D}$ for dike height.

4. **Decision levers** are shown in bold: **W**, **R**, **P**, **D**, **B**.

5. **Equation 6 (Dike Volume)**: The reference C++ code contains a bug where a constant `dh=5` is used instead of the cost height `ch`. Implement using `h` (cost height) as shown in the paper equation.

6. **Equation 8 (Dike Failure)**: The corrected piecewise form is verified against the reference C++ code, which calculates `((surge/D) - threshold) / (1 - threshold)` — algebraically equivalent to the corrected form above.

7. **Implementation guidance** (code vs paper):
   - **Trust the code for parameters**: Use $f_{exp} = 0.115$, $t_{exp} = 0.4$, $f_{failed} = 1.5$, $P_{min} = 0.05$ (these differ from Table 3/4 but reflect the actual implementation)
   - **Trust the code for logic**: Use the code's Equation 8 (failure probability) and damage calculations (intact vs failed factors)
   - **Trust the paper for geometry**: Use the paper's Equation 6 (Dike Volume) — the code has a variable naming collision (`dh=5`) that injects incorrect values
   - **Don't forget hidden factors**: $f_{adj} = 1.25$ (resistance adjustment) and $f_{runup} = 1.1$ (wave runup) are in the code but not prominently shown in the paper
