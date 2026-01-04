# Technical Specification: `iCOW.jl`

## Summary

The **Island City on a Wedge (iCOW)** model is an intermediate-complexity framework for simulating coastal storm surge risk and optimizing mitigation strategies.
Originally developed by Ceres et al. (2019), it bridges the gap between simple economic models (like Van Dantzig) and computationally expensive hydrodynamic models.

The model simulates a city located on a rising coastal "wedge".
It evaluates the trade-offs between two conflicting objectives:

1. **Minimizing Investment:** Costs of withdrawal, flood-proofing (resistance), and building dikes.
2. **Minimizing Damages:** Economic loss from storm surges over time.

**Project Goal:** Implement a performant, modular Julia version of iCOW that supports:

- **Static Optimization:** Replicating the paper's results (Pareto front analysis).
- **Dynamic Policy Search:** Optimizing adaptive rules (e.g., "raise dike if surge > $x$") under deep uncertainty.
- **Forward Mode Analysis:** Generating rich, high-dimensional datasets (Time $\times$ Scenarios $\times$ Strategies) for visualization via YAXArrays.jl.
- **Dual Simulation Modes:** Both stochastic (time series) and Expected Annual Damage (EAD) modes.

**Licensing:** This implementation must be compatible with GPLv3 open-source licensing, following the spirit of the original model release.

## Simulation Modes

The model supports two distinct evaluation modes:

### Stochastic Mode

- **Input:** Actual time series of storm surges (one realization of uncertainty)
- **Output:** Realized costs and damages for that specific scenario
- **Evaluation:** Must run many scenarios (e.g., 1000-5000) to characterize stochasticity and explore uncertainties
- **Use cases:**
  - Characterizing randomness in surge realizations
  - Distributional analysis (percentiles, tail risk)
  - Realistic adaptive policies (respond to actual events)
  - Validation and robustness testing
- **Computational cost:** High (many scenario simulations)

### Expected Annual Damage (EAD) Mode

- **Input:** Probability distributions of storm surges (one per year)
- **Output:** Expected costs and expected damages
- **Evaluation:** Single simulation run integrates over stochastic uncertainty
- **Use cases:**
  - Fast policy exploration and optimization
  - Static policies (all decisions at t=0)
  - Initial Pareto front generation
  - Efficient exploration when stochasticity is well-characterized
- **Computational cost:** Low per scenario (single evaluation with integration)
- **Convergence:** Should match mean of stochastic mode for static policies (Law of Large Numbers)

### Exploring Deeper Uncertainties

**Both modes require many scenarios to explore deeper uncertainties:**

- Parameter uncertainty (city value, damage fractions, cost parameters)
- Structural uncertainty (sea level rise trends, distribution parameters)
- Model uncertainty (alternative damage functions, climate scenarios)

**The difference:**

- **Stochastic mode:** Each scenario requires ~1000 surge realizations to characterize randomness
- **EAD mode:** Each scenario integrates over randomness analytically, so exploring deeper uncertainties is much faster

## Design Principles

1. **Functional Core, Mutable Shell:**
   - Physics calculations (cost, volume, damage) must be **pure functions**. They take parameters and return values with no side effects.
   - State (current year, accumulated cost) is managed only within the Simulation Engine loop.

2. **Allocation-Free Inner Loops:**
   - The optimization loop will run millions of evaluations. Avoid creating temporary arrays or structs inside the simulate function.
   - Use StaticArrays.jl for small coordinate vectors if necessary, though scalars are likely sufficient.

3. **Strict Separation of "Brain" and "Body":**
   - **Body (Physics):** Determines *how much* a 5m dike costs and *how much* damage a 3m surge causes.
   - **Brain (Policy):** Determines *when* to build that dike.
   - The simulation engine should not care if the decision came from a static array or a neural network.

4. **Powell Framework for Sequential Decisions:**
   - **State $S_t$:** Current protection levels, accumulated metrics, history (physical state $R_t$ plus information $I_t$)
   - **Decision $x_t$:** Lever settings (W, R, P, D, B), determined by policy $X^\pi(S_t)$
   - **Exogenous information $W_{t+1}$:** Storm surge forcing (realized or distributional)
   - **Transition function $S^M(S_t, x_t, W_{t+1})$:** State update with irreversibility enforcement
   - **Contribution $C(S_t, x_t, W_{t+1})$:** Investment costs plus damages (may depend on realized surge)
   - **Objective:** $\max_\pi \mathbb{E}\left\{\sum_{t=0}^{T} C(S_t, X^\pi(S_t), W_{t+1}) \mid S_0\right\}$
   - **Policy search:** Policies are parameterized $\pi = (f, \theta)$ where $f$ is the rule type and $\theta$ are tunable parameters

5. **Data as an Artifact:**
   - Surge scenarios (States of the World) are pre-generated and passed as inputs.
   - The simulation functions should be deterministic given specific forcing inputs.

6. **Type Parameterization:**
   - Use `T<:Real` throughout to avoid writing `Float64` everywhere
   - Maintain type stability for performance
   - Default to `Float64` when type is ambiguous

7. **Correctness Over Performance:**
   - Code clarity and correctness are primary goals.
   - Performance optimization is secondary and will be addressed via profiling if needed.

## Implementation Phases

| Phase | Title | Status | Detail File |
|-------|-------|--------|-------------|
| 1 | Parameters & Validation | Completed | [phase01_parameters.md](phase01_parameters.md) |
| 2 | Type System and Mode Design | Completed | [phase02_type_system.md](phase02_type_system.md) |
| 3 | Geometry | Completed | [phase03_geometry.md](phase03_geometry.md) |
| 4 | Core Physics - Costs and Dike Failure | Completed | [phase04_costs.md](phase04_costs.md) |
| 5 | Zones & Event Damage | Completed | [phase05_zones.md](phase05_zones.md) |
| 6 | Expected Annual Damage Integration | Completed | [phase06_ead.md](phase06_ead.md) |
| 7 | Simulation Engine | Completed | [phase07_simulation.md](phase07_simulation.md) |
| 8 | Policies | Completed | [phase08_policies.md](phase08_policies.md) |
| 9 | Optimization | Completed | [phase09_optimization.md](phase09_optimization.md) |
| 10 | Analysis & Aggregation | Pending | [phase10_analysis.md](phase10_analysis.md) |
| 11 | SOW Architecture | Pending | [phase11_sow.md](phase11_sow.md) |
| 12 | Adaptive Policy Infrastructure | Pending | [phase12_adaptive.md](phase12_adaptive.md) |

## Package Structure

```
ICOW.jl/
├── Project.toml
├── README.md
├── LICENSE
├── CLAUDE.md
├── docs/
│   ├── README.md
│   ├── roadmap/                 # This folder
│   │   ├── README.md            # This file
│   │   └── phase*.md            # Phase detail files
│   ├── framework.md             # Theoretical framework
│   ├── equations.md             # All equations from paper
│   ├── parameters.md            # Parameter documentation
│   ├── zones.md                 # Zone structure documentation
│   └── figures/
├── src/
│   ├── ICOW.jl                  # Main module file
│   ├── types.jl                 # Abstract types, Levers
│   ├── parameters.jl            # CityParameters (concrete scalars)
│   ├── forcing.jl               # Forcing types (Stochastic/Distributional, ModelClock)
│   ├── states.jl                # State types (Stochastic/EAD)
│   ├── policies.jl              # Policy interface
│   ├── geometry.jl              # Dike volume (Equation 6)
│   ├── costs.jl                 # Investment costs with bounds checking
│   ├── damage.jl                # Event and EAD damage
│   ├── zones.jl                 # Fixed-size zone structure (5 zones)
│   ├── simulation.jl            # Unified simulation with dispatch (returns raw flows)
│   ├── objectives.jl            # Discounting and objective functions
│   ├── optimization.jl          # NSGA-II interface
│   ├── analysis.jl              # Forward mode (standard Arrays/NamedTuples)
│   └── surges.jl                # Surge generation
├── ext/                         # Optional package extensions
│   └── YAXArraysExt.jl          # YAXArrays conversion (optional)
└── test/
    ├── runtests.jl
    └── *_tests.jl               # Test files for each module
```

## Implementation Checklist

See individual phase files for detailed checklists.
Summary of completion status:

- [x] Phase 1: Parameters & Validation
- [x] Phase 2: Type System and Mode Design
- [x] Phase 3: Geometry
- [x] Phase 4: Core Physics - Costs and Dike Failure
- [x] Phase 5: Zones & Event Damage
- [x] Phase 6: Expected Annual Damage Integration
- [x] Phase 7: Simulation Engine
- [x] Phase 8: Policies
- [x] Phase 9: Optimization
- [ ] Phase 10: Analysis & Aggregation
- [ ] Phase 11: SOW Architecture
- [ ] Phase 12: Adaptive Policy Infrastructure

### C++ Reference Validation

**Status:** ✅ Completed (Jan 2026)

A debugged version of the C++ reference implementation has been created for validation:

- **Location:** `test/cpp_reference/`
- **Bugs Fixed:** 7 total (5 in dike volume, 2 in resistance cost)
- **Validation:** All Julia implementations match corrected C++ within floating-point precision (rtol=1e-10)
- **Documentation:** All bugs documented in `docs/equations.md`
- **Test Coverage:** 8 test cases covering edge cases, zero inputs, and typical scenarios

This provides:

1. Independent verification that Julia matches paper formulas exactly
2. Regression testing infrastructure for future changes
3. Executable reference for correct calculations

See `CLAUDE.md` for usage instructions.

### Documentation & Release

- [ ] Complete all `docs/*.md` files
- [ ] Write `README.md` with examples showing both modes
- [ ] Add GPLv3 `LICENSE` file
- [ ] Create example notebooks
- [ ] Run full test suite
- [ ] Profile performance (both modes)
- [x] C++ reference validation completed
- [ ] Tag v0.1.0 release
