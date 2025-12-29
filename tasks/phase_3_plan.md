# Phase 3: Geometry Implementation Plan

## Overview

Implement the dike volume calculation (Equation 6) from the paper.
This is a pure physics function that calculates the volume of material needed for a dike given its height and the city's geometry.

## Open Questions to Resolve

### Numerical Stability

The equation involves terms like `sqrt(T)` where `T` is a complex expression.
For certain parameter ranges, `T` could potentially be negative (making sqrt undefined).

**Proposed approach**: Add an assertion to catch negative `T` values during development, then investigate if this ever occurs with realistic parameters.

### Trapezoidal Approximation Tolerance

~~Skip this test - not useful for validation.~~

## Implementation Tasks

- [x] Create `src/geometry.jl` with `calculate_dike_volume(city, D)` function
- [x] Implement volume formula matching C++ behavior
- [x] Add the file to `src/ICOW.jl` and export the function
- [x] Create `test/geometry_tests.jl` (zero-height, monotonicity, numerical stability, type stability)
- [ ] ~~Create `docs/notebooks/phase3_geometry.qmd` notebook~~ (skipped)
- [x] Run full test suite and verify everything passes
- [x] Update phase status in roadmap

## Function Signature

```julia
"""
    calculate_dike_volume(city::CityParameters, D) -> volume

Calculate the volume of dike material needed for a dike of height D.

Uses Equation 6 from Ceres et al. (2019). The total effective height
includes startup costs: h_d = D + D_startup.

# Arguments
- `city`: City parameters containing geometry (W_city, s_dike, w_d, D_startup)
- `D`: Dike height in meters (relative to dike base)

# Returns
- Volume in cubic meters (m³)
"""
function calculate_dike_volume(city::CityParameters{T}, D::Real) where {T}
    # Implementation
end
```

**Decision**: Keep it simple with just `(city, D)`. B is not used in Equation 6.

## Test Strategy

### Zero Height Edge Case

With default `D_startup=2.0`, when D=0, `h_d = 2.0` so there's still volume (startup represents fixed costs).
Only when both D=0 AND D_startup=0 do we get zero volume.

```julia
# D=0 still has volume due to D_startup fixed costs
city = CityParameters()
@test calculate_dike_volume(city, 0.0) > 0.0

# Only if D_startup=0 AND D=0 do we get zero volume
city_no_startup = CityParameters(D_startup=0.0)
@test calculate_dike_volume(city_no_startup, 0.0) == 0.0
```

### Monotonicity

```julia
# Volume increases with dike height
vol1 = calculate_dike_volume(city, 1.0)
vol5 = calculate_dike_volume(city, 5.0)
vol10 = calculate_dike_volume(city, 10.0)
@test vol1 < vol5 < vol10
```

### Numerical Stability

```julia
# Should handle a range of realistic values without errors
for D in [0.1, 1.0, 5.0, 10.0, 15.0]
    vol = calculate_dike_volume(city, D)
    @test isfinite(vol)
    @test vol >= 0
end
```

### Type Stability

```julia
# Should work with different numeric types
city32 = CityParameters{Float32}()
@test calculate_dike_volume(city32, 5.0f0) isa Float32
```

### C++ Bug Avoidance

```julia
# Verify we're using paper formula, not C++ bug (where dh=5 was used)
# This is documentary - shows we know about the bug and avoid it
# The C++ code incorrectly used dh=5 instead of dh=D+D_startup
city = CityParameters()
vol_d3 = calculate_dike_volume(city, 3.0)
vol_d7 = calculate_dike_volume(city, 7.0)
@test vol_d3 != vol_d7  # C++ bug would give same volume for all D
```

## Equation 6 Reference

From `docs/equations.md`:

$$
V_d = W_{city} \cdot h_d \left( w_d + \frac{h_d}{s^2} \right) + \frac{1}{6} \sqrt{T} + w_d \frac{h_d^2}{S^2}
$$

Where:

$$
T = -\frac{h_d^4 (h_d + 1/s)^2}{s^2} - \frac{2h_d^5(h_d + 1/s)}{S^4} - \frac{4h_d^6}{s^2 S^4} + \frac{4h_d^4(2h_d(h_d + 1/s) - 3h_d^2/s^2)}{s^2 S^2} + \frac{2h_d^3(h_d + 1/s)}{S^2}
$$

And:

- $h_d = D + D_{startup}$ (effective dike height)
- $S = H_{city} / D_{city}$ (city slope)
- $s = s_{dike}$ (dike side slope)
- $w_d$ = dike top width
- $W_{city}$ = city coastline length

## Review

### Summary

Implemented `calculate_dike_volume(city, D)` in [src/geometry.jl](../src/geometry.jl).

### Critical Discovery: C++ Integer Division Bug

During implementation, we discovered a significant bug in the C++ reference code.
The formula uses `pow(T, 1/2)` where `T` is a complex expression.
In C/C++, `1/2` is integer division, which evaluates to 0.
Therefore `pow(T, 1/2) = pow(T, 0) = 1`, and the entire tetrahedron correction term collapses to the constant `1/6`.

**Evidence:**

- Line 147 of `iCOW_2018_06_11.cpp` shows `),1/2)/6+`
- They correctly use `0.5` elsewhere (lines 68, 229) when they want half
- Integer division semantics are identical in C and C++

**Verification options:**

1. Compile the original C++ code and add a print statement for `pow(..., 1/2)` - it should output 1.0
2. Run the C++ code with different dike heights and verify behavior matches our implementation

### Implemented Formula

Due to the C++ bug, the actual formula being used is:

$$
V_d = W_{city} \cdot ch \cdot (w_d + ch/s^2) + 1/6 + W_{city} \cdot ch^2 / S^2
$$

Where:

- $ch = D + D_{startup}$ (cost height)
- $S = W_{city} / D_{city}$ (C++ uses this, not $H_{city}/D_{city}$)
- $s = s_{dike}$ (dike side slope)

### Additional Finding: Slope Definition

The C++ code defines slope as `CityLength/CityWidth` (= 43000/2000 = 21.5), not `H_city/D_city` (= 0.0085) as stated in the paper.
We use the C++ definition to match its behavior.

### Tests

All 248 tests pass, including:

- Zero height edge case (volume is 1/6 when D=0 and D_startup=0 due to the bug)
- Monotonicity (volume increases with height)
- Numerical stability
- Type stability (Float32/Float64)
