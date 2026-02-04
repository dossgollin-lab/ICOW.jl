# Mathematical Audit Report: ICOW.jl

**Audit Date:** February 2026
**Auditor:** Claude (Opus 4.5)
**Scope:** Mathematical correctness of Julia implementation vs `equations.md`
**Source of Truth:** `_background/equations.md`

## Executive Summary

The ICOW.jl implementation is **largely correct** with respect to the documented equations.
Most Core functions match the equations exactly.
However, this audit identified:

- **1 Critical Bug**: Resistance cost incorrectly returns 0 for "resistance-only" strategies (B=0, D=0, R>0)
- **2 Medium Issues**: C++ validation harness slope error (non-impacting); fragile division-by-zero guard
- **3 Documentation Gaps**: Missing clarifications that could mislead developers
- **4 Test Coverage Gaps**: Damage calculations and several edge cases lack validation

---

## 1. Core Module: Equation-by-Equation Audit

### Equation 1: Withdrawal Cost ✅ PASS

**equations.md:**
$$C_W = \frac{V_{city} \cdot W \cdot f_w}{H_{city} - W}$$

**costs.jl:11:**
```julia
return V_city * W * f_w / (H_city - W)
```

**Verdict:** Exact match.

---

### Equation 2: Value After Withdrawal ✅ PASS

**equations.md:**
$$V_w = V_{city} \cdot \left(1 - \frac{f_l \cdot W}{H_{city}}\right)$$

**costs.jl:20-21:**
```julia
loss_fraction = f_l * W / H_city
return V_city * (one(T) - loss_fraction)
```

**Verdict:** Exact match.

---

### Equation 3: Resistance Cost Fraction ✅ PASS

**equations.md:**
$$f_{cR} = f_{adj} \cdot \left( f_{lin} \cdot P + \frac{f_{exp} \cdot \max(0, P - t_{exp})}{1 - P} \right)$$

**costs.jl:32-35:**
```julia
linear_term = f_lin * P
exponential_numerator = f_exp * max(zero(T), P - t_exp)
exponential_term = exponential_numerator / (one(T) - P)
return f_adj * (linear_term + exponential_term)
```

**Verdict:** Exact match.

---

### Equations 4-5: Resistance Cost ⚠️ ISSUE FOUND

**equations.md:**
- **Eq 4** (when $R < B$ **or no dike**): $C_R = \frac{V_w \cdot f_{cR} \cdot R \cdot (R/2 + b)}{H_{bldg} \cdot (H_{city} - W)}$
- **Eq 5** (when $R \geq B$): $C_R = \frac{V_w \cdot f_{cR} \cdot B \cdot (R - B/2 + b)}{H_{bldg} \cdot (H_{city} - W)}$

**costs.jl:50-56:**
```julia
if R < B
    numerator = V_w * f_cR * R * (R / 2 + b_basement)  # Eq 4
else
    numerator = V_w * f_cR * B * (R - B / 2 + b_basement)  # Eq 5
end
```

**Issue:** The "or no dike" condition from Eq 4 is **not implemented**.

When B=0 and D=0 (no dike, no setback), the code uses Eq 5 (because $R \geq B = 0$), which multiplies by B=0, returning **zero cost** even when R>0 and P>0.

**Example:**
- Input: W=0, R=4, P=0.5, D=0, B=0
- Expected (Eq 4): $C_R = \frac{1.5 \times 10^{12} \cdot 0.2475 \cdot 4 \cdot 5}{30 \cdot 17} \approx \$14.56B$
- Actual (Julia): $C_R = 0$ (because Eq 5 multiplies by B=0)

**Impact:** "Resistance-only" strategies (flood-proofing without any dike) are rendered costless, which is mathematically incorrect.

**Note:** The C++ reference also returns 0 for this case, but through a different mechanism (it sets `rh=0` when `B < minHeight`). The validation passes because both implementations have equivalent bugs.

**Recommended Fix:**
```julia
if R < B || (B == zero(T) && D == zero(T))
    # Eq 4: unconstrained (no dike to cap resistance)
    numerator = V_w * f_cR * R * (R / 2 + b_basement)
else
    # Eq 5: constrained (resistance capped at dike base)
    numerator = V_w * f_cR * B * (R - B / 2 + b_basement)
end
```

---

### Equation 6: Dike Volume ✅ PASS (Intentionally Different)

**equations.md:** Documents that Julia uses a **simplified geometric formula** because the paper's formula is numerically unstable.

**geometry.jl:**
```julia
V_main = W_city * h_d * (w_d + slope_width)
V_wings = (h_d * h_d / S) * (w_d + (T(2) / T(3)) * slope_width)
```

**Verification against equations.md formula:**
- Main seawall: $W_{city} \cdot h_d \cdot (w_d + h_d/s^2)$ ✅
- Side wings: $\frac{h_d^2}{S} \cdot (w_d + \frac{2h_d}{3s^2})$ ✅

**Verdict:** Exact match with documented simplified formula.

---

### Equation 7: Dike Cost ✅ PASS

**equations.md:** $C_D = V_d \cdot c_d$

**costs.jl:67:** `return V_dike * c_d`

**Verdict:** Exact match.

---

### Effective Surge ✅ PASS

**equations.md:**
$$h_{eff} = \begin{cases} 0 & \text{if } h_{raw} \leq H_{seawall} \\ h_{raw} \cdot f_{runup} - H_{seawall} & \text{otherwise} \end{cases}$$

**costs.jl:75-80:**
```julia
if h_raw <= H_seawall
    return zero(T)
else
    return h_raw * f_runup - H_seawall
end
```

**Verdict:** Exact match.

---

### Equation 8: Dike Failure Probability ✅ PASS (with note)

**equations.md piecewise formula:**
$$p_{fail} = \begin{cases} p_{min} & \text{if } h < t_{fail} \cdot D \\ \frac{h - t_{fail} \cdot D}{D(1 - t_{fail})} & \text{if } t_{fail} \cdot D \leq h < D \\ 1.0 & \text{if } h \geq D \end{cases}$$

**costs.jl:97-107:** Exact implementation of piecewise formula.

**Edge case (D=0):** The code has special handling (lines 92-95) that returns `p_min` if surge=0, else 1.0. This is reasonable but undocumented.

**Fragility note:** If `t_fail = 1.0`, the denominator `D * (1 - t_fail) = 0`. Currently unreachable due to branch logic, but fragile for future changes.

---

### Zone Boundaries (Figure 3) ✅ PASS

**zones.jl** exactly matches equations.md zone definitions:
- Zone 0: $[0, W]$
- Zone 1: $[W, W + \min(R, B)]$
- Zone 2: $[W + \min(R, B), W + B]$
- Zone 3: $[W + B, W + B + D]$
- Zone 4: $[W + B + D, H_{city}]$

---

### Zone Values ✅ PASS (with documentation note)

**zones.jl:42-45:**
```julia
val_z1 = V_w * r_unprot * min(R, B) / remaining_height
val_z2 = V_w * r_unprot * max(zero(T), B - R) / remaining_height
val_z3 = V_w * r_prot * D / remaining_height
val_z4 = V_w * (remaining_height - B - D) / remaining_height
```

**Note:** Zone 2 uses `max(zero(T), B - R)` which is correct behavior (handles $R \geq B$), but equations.md doesn't explicitly show the max() clause. Consider updating documentation.

---

### Equation 9: Damage Calculations ✅ PASS

**damage.jl** correctly implements:
- Base zone damage with flood fraction calculation
- Zone-specific modifiers (resistance factor for Zone 1, dike factor for Zone 3)
- Threshold penalty formula

---

## 2. C++ Validation Harness Audit

### Bug Fix Verification

| Bug # | Description | Status | Notes |
|-------|-------------|--------|-------|
| 1 | Integer division `pow(T, 1/2)` → `sqrt(T)` | ✅ Fixed | Line 166 |
| 2 | Array index `dh=5` → `ch` | ✅ Fixed | Line 159 |
| 3 | Algebraic coefficient error | ✅ Fixed | Line 161 |
| 4 | Variable `W` → `wdt` | ✅ Fixed | Line 169 |
| 5 | Slope definition | ⚠️ Incorrect | See below |
| 6 | Resistance cost using `V_w` | ✅ Fixed | Lines 201, 216 |
| 7 | V_w calculation | ✅ Fixed | Line 366 |

### Bug 5 Issue: Slope Definition

**icow_debugged.cpp:48:**
```cpp
const double CitySlope=CityWidth/CityLength;  // = 21.5
```

**equations.md:** $S = H_{city}/D_{city} = 17/2000 = 0.0085$

The C++ uses `43000/2000 = 21.5`, not `17/2000 = 0.0085`.

**Impact:** None for validation, because:
1. Slope is only used in dike volume calculation
2. Dike cost is explicitly excluded from validation (documented in test file)
3. All validated quantities (withdrawal cost, resistance cost, zone values) don't use slope

**Recommendation:** Fix the C++ for documentation correctness, even though it doesn't affect tests.

---

## 3. Simulation Module Audit

### Policy Reparameterization ✅ PASS

**Stochastic/types.jl:161-170** and **EAD/types.jl:191-200:**

The stick-breaking reparameterization correctly ensures:
- $W + B + D \leq H_{city}$ (guaranteed by construction)
- Boundary case $W = H_{city}$ handled by feasibility check returning `Inf`

### Discounting Formula ✅ PASS (with documentation note)

**simulation.jl:130:**
```julia
df = one(T) / (one(T) + r)^year
```

This is **end-of-year discounting**: year 1 costs are discounted by $1/(1+r)$.

**Note:** The equations.md shows $C_{total} + \sum d \cdot \delta^t$, implying investment is not discounted. However, with static policies where investment occurs in year 1, both interpretations are equivalent up to a constant factor. Consider documenting the timing convention.

### EAD Integration ✅ PASS

**EAD/simulation.jl:237-238:**
```julia
h_min = T(quantile(dist, 0.0001))
h_max = T(quantile(dist, 0.9999))
```

Truncates to 0.01-99.99 percentile range. For typical GEV parameters, this captures essentially all probability mass. Acceptable numerical approximation.

---

## 4. Test Coverage Analysis

### What IS Validated Against C++

| Function | Validated | Tolerance |
|----------|-----------|-----------|
| `withdrawal_cost` | ✅ | rtol=1e-10 |
| `value_after_withdrawal` | ✅ | rtol=1e-10 |
| `resistance_cost` | ✅ | rtol=1e-10 |
| `zone_boundaries` | ✅ | rtol=1e-10 |
| `zone_values` | ✅ | rtol=1e-10 |

### What is NOT Validated

| Function | Reason | Risk |
|----------|--------|------|
| `dike_volume` | Different formula (intentional) | Low - documented |
| `dike_cost` | Depends on dike_volume | Low |
| `effective_surge` | Not in C++ test output | Medium |
| `dike_failure_probability` | Not in C++ test output | Medium |
| `base_zone_damage` | Not in C++ test output | **High** |
| `zone_damage` | Not in C++ test output | **High** |
| `total_event_damage` | Not in C++ test output | **High** |
| `expected_damage_given_surge` | Not in C++ test output | **High** |

### Missing Test Cases

1. **Resistance-only strategy** (B=0, D=0, R>0, P>0): Would reveal the Eq 4/5 bug
2. **Damage calculation validation**: No external reference for damage formulas
3. **Dike failure edge cases**: `D=0`, `t_fail=1.0`, `h_surge` exactly at threshold
4. **Threshold penalty**: No test verifies the penalty calculation

---

## 5. Summary of Issues

### Critical

| ID | Issue | Location | Impact |
|----|-------|----------|--------|
| C1 | Resistance cost returns 0 when B=0, even if R>0 | costs.jl:50-56 | "Resistance-only" strategies broken |

### Medium

| ID | Issue | Location | Impact |
|----|-------|----------|--------|
| M1 | C++ slope = 21.5, should be 0.0085 | icow_debugged.cpp:48 | None (not used in validation) |
| M2 | Fragile division by zero if t_fail=1.0 | costs.jl:103 | Currently unreachable |

### Documentation

| ID | Issue | Location | Recommendation |
|----|-------|----------|----------------|
| D1 | Zone 2 formula missing max() | equations.md:244 | Add `max(0, B-R)` |
| D2 | Eq 4 "no dike" condition not in code | equations.md:118 | Either fix code or clarify docs |
| D3 | Discounting convention undocumented | equations.md | Add timing convention note |

### Test Coverage

| ID | Gap | Recommendation |
|----|-----|----------------|
| T1 | Damage functions not validated | Add C++ damage output or hand calculations |
| T2 | Resistance-only case not tested | Add test case W=0, R=4, P=0.5, D=0, B=0 |
| T3 | Dike failure edge cases | Add tests for D=0, threshold boundaries |
| T4 | Threshold penalty | Add test verifying penalty calculation |

---

## 6. Recommendations

### Immediate (Before Next Release)

1. **Fix C1**: Implement "no dike" condition in resistance_cost:
   ```julia
   if R < B || (B == zero(T) && D == zero(T))
   ```
   **STATUS: FIXED** (February 2026)

2. **Add T2**: Test case for resistance-only strategy that would catch C1
   **STATUS: FIXED** (February 2026)

### Short-term

3. **Fix M1**: Correct C++ slope for documentation accuracy
   **STATUS: FIXED** (February 2026) - Changed to `CEC/CityLength = 0.0085`

4. **Fix M2**: Add guard for `t_fail >= 1.0` in dike_failure_probability
   **STATUS: FIXED** (February 2026)

5. **Update D1-D3**: Clarify documentation
   **STATUS: PARTIALLY ADDRESSED** - Bug #8 documented in equations.md and docs/equations.qmd

### Long-term

6. **Add T3-T4**: Comprehensive edge case testing
   **STATUS: FIXED** (February 2026) - Added `test/core/edge_cases_tests.jl`

7. **Consider**: Symbolic verification of damage formulas against paper

---

## Appendix: Files Audited

- `src/Core/costs.jl` - Cost functions (Eq 1-5, 7-8)
- `src/Core/geometry.jl` - Dike volume (Eq 6)
- `src/Core/zones.jl` - Zone boundaries and values
- `src/Core/damage.jl` - Damage calculations (Eq 9)
- `src/types.jl` - FloodDefenses struct
- `src/Stochastic/types.jl` - Policy reparameterization
- `src/Stochastic/simulation.jl` - Simulation callbacks
- `src/EAD/types.jl` - EAD types
- `src/EAD/simulation.jl` - EAD integration
- `test/validation/cpp_reference/icow_debugged.cpp` - C++ reference
- `test/core/cpp_validation_tests.jl` - Validation tests
- `_background/equations.md` - Mathematical reference
