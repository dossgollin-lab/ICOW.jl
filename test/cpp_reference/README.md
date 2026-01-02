# C++ Reference Validation

This directory contains a debugged version of the original C++ implementation for validation purposes.

## Purpose

The original C++ implementation (`iCOW_2018_06_11.cpp`) contains 7 mathematical bugs that were used in the Ceres et al. (2019) paper.
This debugged version fixes all bugs to match the paper formulas exactly, providing:

1. **Independent verification** that the Julia implementation is correct
2. **Regression testing** to prevent bugs during refactoring
3. **Executable documentation** of correct calculations

## Files

- `icow_debugged.cpp` - C++ code with all 7 bugs fixed (tracked in git)
- `compile.sh` - Build script (requires Homebrew g++-15 on macOS)
- `outputs/` - Generated reference outputs (not tracked in git)
  - `costs.txt` - Cost calculations for all test cases
  - `zones.txt` - Zone geometry for all test cases
  - `summary.txt` - Metadata about the debugged version
- `validate_cpp_outputs.jl` - Julia validation script
- `check_params.jl` - Helper script to check parameters
- `debug_resistance.jl` - Helper script for debugging resistance costs

## Bugs Fixed

See `docs/equations.md` for complete documentation. Summary:

### Dike Volume (Equation 6)
1. Integer division: `pow(T, 1/2)` → `sqrt(T)`
2. Array index: hardcoded `dh=5` → actual `ch` variable
3. Algebraic error: `-4*ch2+ch2/sd^2` → `-3*ch2/sd^2`
4. Wrong variable: `W` (city width) → `wdt` (dike top width)
5. Slope definition: swapped to `W_city/D_city` = 21.5

### Resistance Cost (Equations 4-5)
6. Used `vz1` (zone value with r_unprot=0.95) → `V_w` (total value)
7. Calculated `V_w = V_city - C_W` → Equation 2: `V_w = V_city * (1 - f_l * W / H_city)`

## Usage

### Building and Running

```bash
# Build the debugged C++ code
./compile.sh

# Generate reference outputs
./icow_test

# Outputs are written to outputs/*.txt
ls outputs/
```

### Validation

```bash
# From project root
julia --project test/cpp_reference/validate_cpp_outputs.jl
```

Expected output:
```
============================================================
Validating Julia implementation against C++ reference
============================================================

--- Testing: zero_case ---
  ✓ Withdrawal cost: Julia=0.0, C++=0.0
  ✓ Resistance cost: Julia=0.0, C++=0.0
  ...

============================================================
✓ All tests passed!
============================================================
```

## Test Cases

8 test cases covering:

1. **zero_case**: All levers = 0 (baseline)
2. **dike_only**: D=5, no other protection
3. **full_protection**: W=2, R=3, P=0.8, D=5, B=1
4. **resistance_only**: R=4, P=0.5, no dike
5. **withdrawal_only**: W=5, no other protection
6. **edge_r_geq_b**: R=6, B=5 (dominated strategy, R ≥ B)
7. **high_surge**: All protections, surge=15 (overtopping)
8. **below_seawall**: surge=1.5 (< 1.75, no effective surge)

## Maintenance

### When to Re-run Validation

Run validation after any changes to:
- `src/costs.jl` (withdrawal, resistance, dike costs)
- `src/geometry.jl` (dike volume)
- `src/zones.jl` (zone value calculations)
- `src/parameters.jl` (default parameters)

### Adding New Test Cases

To add a new test case:

1. Edit `icow_debugged.cpp`, add to the `test_cases` vector in `main()`:
   ```cpp
   {"my_test", W, R, P, D, B, surge}
   ```

2. Recompile and regenerate outputs:
   ```bash
   ./compile.sh && ./icow_test
   ```

3. Update `validate_cpp_outputs.jl` if testing new functions

### If Validation Fails

1. Check `docs/equations.md` for the correct formula
2. Compare Julia code to paper equations
3. Check if a new C++ bug was discovered
4. If new bug found, document it in `docs/equations.md` and fix in `icow_debugged.cpp`

## Compilation Requirements

**macOS:**
- Requires Homebrew g++-15: `brew install gcc`
- Clang++ (default on macOS) has missing C++ standard library headers

**Linux:**
- Should work with system g++

**Windows:**
- MinGW or Visual Studio should work (untested)

## Validation Tolerance

Tests use `rtol=1e-10` (relative tolerance), which is appropriate for:
- Floating-point arithmetic precision
- Ensuring identical calculations between C++ and Julia
- Catching actual implementation differences vs numerical noise
