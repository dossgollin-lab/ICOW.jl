# Test Directory

This directory contains tests for ICOW.jl, organized into two categories.

## Unit Tests (Run Frequently)

```bash
julia --project test/runtests.jl
```

These are fast, automated tests that should pass after every change.
They verify core functionality: parameters, types, costs, damage, zones, simulation, and optimization.

**Files**: `*_tests.jl` and `runtests.jl`

## Validation Scripts (Run As Needed)

Located in `validation/`, these are qualitative checks for verifying correctness against reference implementations or expected behaviors.

### C++ Reference Validation

```bash
julia --project test/validation/cpp_reference/validate_cpp_outputs.jl
```

Validates Julia implementation against a debugged C++ reference.
Run after changes to physics (`src/costs.jl`, `src/geometry.jl`, `src/zones.jl`).

**Note**: Dike volume uses a corrected formula in Julia (see `_background/equations.md`), so dike/total costs are skipped.

### Mode Convergence

```bash
julia --project test/validation/validate_mode_convergence.jl
```

Verifies that EAD mode converges to mean(stochastic mode) as expected by the Law of Large Numbers.
Run after changes to simulation logic.

### EAD Benchmarks

```bash
julia --project test/validation/benchmark_ead_methods.jl
```

Compares QuadGK (adaptive quadrature) vs Monte Carlo for EAD integration.
Useful for verifying accuracy and performance trade-offs.

### Debug Scripts

```bash
julia --project test/validation/debug_zone_damage.jl
```

Diagnostic script for investigating zone damage calculations.
