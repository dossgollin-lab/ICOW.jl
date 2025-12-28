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
- **Forward Mode Analysis:** Generating rich, high-dimensional datasets (Time × Scenarios × Strategies) for visualization via YAXArrays.jl.
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

## Implementation Roadmap

### Phase 1: Parameters & Validation

**Goal:** Establish the foundational parameter types and constraint validation.

**Deliverables:**

- [x] `src/parameters.jl` - Parameterized `CityParameters{T}` struct with all exogenous parameters from Table C.3
- [x] `src/types.jl` - Parameterized `Levers{T}` struct with physical constraint validation
- [x] `docs/parameters.md` - Documentation of all parameters with symbols, units, and physical interpretation
- [x] Validation function `validate_parameters()` for physical consistency
- [x] Feasibility check `is_feasible()` for lever constraints
- [x] Comprehensive tests covering:
  - Parameter construction and validation
  - Lever constraint enforcement
  - Type conversions and defaults
  - Edge cases and boundary conditions
- [x] `docs/notebooks/phase1_parameters.qmd` - Quarto notebook illustrating Phase 1 features

**Key Design Decisions:**

- Manual keyword constructor with defaults (allows computed defaults like `d_thresh = V_city/375`)
- Parameterize by `T<:Real` to avoid writing `Float64` everywhere
- Strict validation with `@assert` in constructors
- `Base.max()` overload for irreversibility enforcement

### Phase 2: Type System and Simulation Mode Design

**Goal:** Define the type system architecture for dual-mode simulation before implementing physics.

This phase establishes the framework for both stochastic and EAD modes without implementing the full physics.
It answers fundamental design questions about how forcing, state, and policies interact.

**Open Questions:**

1. **Scope of initial implementation:** Which convenience constructors and helpers are essential vs future enhancements?
2. **State update semantics:** Should state fields be updated in-place or should we return modified copies?

**Deliverables:**

- [ ] `docs/simulation_modes.md` - Comprehensive documentation explaining:
  - Conceptual overview of stochastic vs EAD modes
  - When to use each mode (decision guide)
  - Powell framework connection (state, decision, exogenous info, transition, objective)
  - Expected convergence behavior
  - Performance characteristics and limitations

- [ ] `src/types.jl` (additions) - Abstract type hierarchy:
  - `AbstractForcing{T<:Real}` interface specification
  - `AbstractSimulationState{T<:Real}`
  - `AbstractPolicy{T<:Real}`

- [ ] `src/forcing.jl` - Forcing types for both modes:
  - `StochasticForcing{T}` - Contains realized surge matrix `[n_scenarios, n_years]`
  - `DistributionalForcing{T,D}` - Contains vector of `Distribution` objects and cached samples
  - `ModelClock` or equivalent structure for mapping simulation years to calendar years/climate trends
  - `calendar_year()` and related temporal mapping functions
  - Constructors and validation
  - **Note:** Forcing objects represent aleatory (stochastic) uncertainty only

- [ ] `src/states.jl` - State types for both modes:
  - `StochasticState{T}` - Tracks realized surges and damages
  - `EADState{T}` - Tracks expected annual damages
  - Constructors from forcing objects

- [ ] `src/policies.jl` - Policy interface:
  - **Callable struct pattern:** `(policy::AbstractPolicy)(state, forcing, year) -> Levers`
  - **Parameter extraction:** `parameters(policy) -> AbstractVector` for optimization
  - **Reconstruction:** Constructor from parameter vector `PolicyType(θ::AbstractVector)`
  - `StaticPolicy{T}` implementation (parameters $\theta$ = lever values directly)
  - Documentation of what policies can observe (state, forcing, current year)

- [ ] `src/parameters.jl` (update):
  - Parameterize `CityParameters{T}` with concrete scalar fields
  - **Important:** Fields remain concrete scalars (not Distributions)
  - Epistemic (deep) uncertainty handled by generating/sampling multiple `CityParameters` objects externally

- [ ] Comprehensive tests covering:
  - Type construction and conversions
  - State initialization from forcing
  - Policy callable interface
  - Type stability verification
  - Calendar year calculations and clock functionality
- [ ] `docs/notebooks/phase2_type_system.qmd` - Quarto notebook illustrating Phase 2 features

**Key Design Decisions:**

- **Modular uncertainty representation:** `AbstractForcing` interface allows "plug and play" of different uncertainty structures (e.g., deep uncertainty with drifting parameters)
- **Temporal mapping:** Forcing objects include clock/mapping to link simulation steps to calendar years for non-stationary trends
- **Epistemic vs aleatory separation:** `CityParameters` stays concrete; deep uncertainty explored by running multiple scenarios with different parameter sets
- Policies receive full forcing object (maximum flexibility for observing exogenous info)
- Sample matrix oriented as `n_scenarios × n_years` for efficient scenario iteration
- Pre-generated cached samples for deterministic, efficient EAD evaluation

**USER REVIEW CHECKPOINT:** Do not proceed to Phase 3 until type system is approved.

### Phase 3: Geometry

**Goal:** Implement the geometrically complex dike volume calculation (Equation 6).

**Open Questions:**

1. **Numerical stability:** Are there parameter ranges where the equation becomes numerically unstable?
2. **Validation reference:** What tolerance should we use when comparing to trapezoidal approximation?

**Deliverables:**

- [ ] Extract Equation 6 from paper to `docs/equations.md` with LaTeX notation
- [ ] `src/geometry.jl` - Implement `calculate_dike_volume(city, D, B)` exactly as specified in paper
- [ ] Validation: Unit test against simple trapezoidal approximation to catch order-of-magnitude errors
- [ ] Comprehensive tests covering:
  - Zero height edge case
  - Monotonicity (volume increases with height)
  - Numerical stability
  - Trapezoidal approximation validation
- [ ] `docs/notebooks/phase3_geometry.qmd` - Quarto notebook illustrating Phase 3 features

**Key Implementation Notes:**

- Equation 6 is geometrically complex due to irregular tetrahedrons on wedge slopes
- **Do not simplify the equation** - implement exactly as specified (no decomposition into helper functions)
- Validate correctness using trapezoidal approximation (sufficient to catch bugs without over-engineering)
- Total height includes startup costs: `h = D + D_startup`
- This is mode-agnostic physics (used by both stochastic and EAD modes)

### Phase 4: Core Physics - Costs and Event Damage

**Goal:** Implement cost and damage functions based on exact equations from the paper.

**Prerequisite:** Complete `docs/equations.md` with all equations (1-9) before implementation.

**Open Questions:**

1. **Edge case handling:** How should we handle division by zero cases (return Inf, throw error, clamp)?
2. **Numerical tolerances:** What tolerance for floating point comparisons in physical constraints?
3. **Constrained resistance:** When R > B (dominated strategy), should we warn, clamp silently, or allow?
4. **Dike failure mechanics:** Should failure be deterministic (use probability as damage weight) or stochastic (sample from probability)?
5. **Simplified damage scope:** How much functionality should the Phase 4 damage function have before full zones in Phase 6?

**Deliverables:**

- [ ] `docs/equations.md` - All equations from Ceres et al. (2019) in LaTeX:
  - Equation 1: Withdrawal cost
  - Equation 2: City value after withdrawal
  - Equation 3: Resistance cost fraction
  - Equations 4-5: Resistance cost (unconstrained and constrained)
  - Equation 6: Dike volume (from Phase 3)
  - Equation 7: Dike cost
  - Equation 8: Dike failure probability
  - Equation 9: Damage by zone
  - Symbol definitions and units

- [ ] `src/costs.jl` - Cost calculation functions:
  - `calculate_withdrawal_cost(city, W)`
  - `calculate_value_after_withdrawal(city, W)`
  - `calculate_resistance_cost_fraction(city, P)` **with bounds checking**
  - `calculate_resistance_cost(city, levers)`
  - `calculate_dike_cost(city, D, B)`
  - `calculate_investment_cost(city, levers)` (total)
  - **Boundary safety:** Implement `check_bounds` or `clamp` logic to ensure P < 1.0 before evaluation

- [ ] `src/damage.jl` - Event damage calculation:
  - `calculate_event_damage(city, levers, surge)` (simplified version)
  - `calculate_dike_failure_probability(surge_height, D, threshold)`
  - Helper functions for damage components

- [ ] Comprehensive tests covering:
  - Cost monotonicity (increasing levers → increasing costs)
  - Zero inputs → zero outputs
  - **Boundary cases:** P → 1.0 handled safely (no division by zero crashes)
  - Edge cases (division by zero avoidance in withdrawal)
  - Cost component validation (sum equals total)
- [ ] `docs/notebooks/phase4_costs.qmd` - Quarto notebook illustrating Phase 4 features

**Key Implementation Notes:**

- **Critical:** Equation 3 has `(1 - P)` denominator - must prevent P ≥ 1.0 to avoid division by zero in optimization
- Event damage calculation is mode-agnostic (single surge realization)
- Used directly by stochastic mode
- Used indirectly by EAD mode (integrated over distribution)
- Simplified version in this phase; full zone-based calculation in Phase 6

### Phase 5: Expected Annual Damage Calculation

**Goal:** Implement integration of event damage over surge distributions for EAD mode.

**Open Questions:**

1. **Sample count defaults:** What's the default `n_samples` for Monte Carlo? Trade-off between accuracy and memory.
2. **Quadrature integration bounds:** For unbounded distributions, what upper quantile should we integrate to?
3. **Convergence tolerance:** What relative tolerance is acceptable for mode convergence tests?

**Deliverables:**

- [ ] `src/damage.jl` (additions):
  - `calculate_expected_damage(city, levers, forcing, year)`
  - Support both Monte Carlo (cached samples) and quadrature integration
  - Dispatch on `forcing.integration_method`

- [ ] Tests covering:
  - Monte Carlo integration using cached samples
  - Numerical quadrature integration
  - Agreement between integration methods
  - Convergence to stochastic mean (Law of Large Numbers)
  - Monotonicity over time for non-stationary distributions
- [ ] `docs/notebooks/phase5_ead.qmd` - Quarto notebook illustrating Phase 5 features

**Key Implementation Notes:**

- Uses cached samples from `DistributionalForcing` for efficiency
- Monte Carlo: `mean(calculate_event_damage.(samples))`
- Quadrature: Integrate `pdf(surge) * damage(surge)` using QuadGK.jl
- Critical validation: EAD ≈ mean(stochastic damages) for same distribution

### Phase 6: Zones & City Characterization

**Goal:** Implement the complete zone-based city model from Figure 3 of the paper.

**Open Questions:**

1. **Zero-width zones:** How should we handle lever configurations that create zones with zero height?
2. **Basement flooding implementation:** How exactly should basement depth interact with zone flooding calculations?

**Deliverables:**

- [ ] `docs/zones.md` - Document zone structure from paper:
  - Zone definitions (0: withdrawn, 1: resistant, 2: unprotected, 3: dike-protected, 4: city heights)
  - Zone interaction logic
  - Damage calculation by zone
  - Figure 3 explanation

- [ ] `src/zones.jl` - Zone-based city model:
  - `CityZone` struct (boundaries, value density, damage modifier, protection status)
  - `calculate_city_zones(city, levers)` - Partition city into exactly 5 zones (fixed-size structure)
  - `calculate_zone_damage(zone, water_level, city)` - Damage per zone
  - **Performance requirement:** Use fixed-size immutable struct (e.g., `StaticArrays.SVector{5}` or `NTuple{5, CityZone}`)
  - **Important:** Do NOT filter out empty zones - set their Volume/Value to 0.0 instead

- [ ] `src/damage.jl` (update):
  - Replace simplified damage with `calculate_event_damage_full()`
  - Zone-by-zone damage accumulation
  - Special handling for dike-protected zone (stochastic failure)
  - Basement flooding effects

- [ ] Tests covering:
  - Zone structure for different lever combinations
  - Correct zone boundaries
  - Damage reduction with protection
  - Dike failure mechanics
  - Monotonicity of damage with surge height
  - Empty zones (zero volume/value) handled correctly
- [ ] `docs/notebooks/phase6_zones.qmd` - Quarto notebook illustrating Phase 6 features

**Key Implementation Notes:**

- **Critical for performance:** Zone structure MUST be fixed-size to avoid allocations in hot loop
- Dynamic resizing kills performance during optimization (millions of evaluations)
- Always return exactly 5 zones, setting Volume=0 and Value=0 for unused zones
- Zone structure depends on lever settings (dynamic geometry)
- Protected zone (3) has probabilistic dike failure
- Resistance applies only up to dike base (or full height if no dike)
- Withdrawal zone (0) has zero value and damage

### Phase 7: Simulation Engine

**Goal:** Unified time-stepping simulation with dispatch on forcing/state types.

**Open Questions:**

1. **Error handling strategy:** How should we handle simulation failures mid-run (numerical errors, constraint violations)?
2. **Trace content:** What variables beyond [year, investment, damage, W, R, P, D, B] should be tracked?

**Deliverables:**

- [ ] `src/simulation.jl` - Core simulation engine:
  - `simulate(city, policy, forcing; mode)` - Main simulation function
  - `initialize_state(forcing)` - Dispatch: StochasticForcing → StochasticState, etc.
  - `calculate_annual_damage(city, levers, state, forcing, year)` - Dispatch on mode
  - `update_state(state, levers, damage, forcing, year)` - Dispatch on mode
  - Helper functions for trace recording and result finalization
  - **Critical:** Irreversibility enforcement: `effective_levers = max(target_levers, current_levers)`
  - **Critical:** Return RAW, UNDISCOUNTED flows (costs and damages by year)

- [ ] `src/objectives.jl` or similar - Post-processing functions:
  - `apply_discounting(flows, discount_rate)` - Apply discount factors to raw flows
  - Objective function wrappers that discount results from simulate()

- [ ] Tests covering:
  - Both simulation modes (stochastic and EAD)
  - Scalar mode (optimization) vs trace mode (analysis)
  - Irreversibility enforcement (protection levels never decrease)
  - **Raw flows returned without discounting**
  - Mode convergence (static policy: EAD ≈ mean(stochastic))
  - State updates and accumulation
- [ ] `docs/notebooks/phase7_simulation.qmd` - Quarto notebook illustrating Phase 7 features

**Key Implementation Notes:**

- **Policy interface:** Policies return TARGET lever state, not final decision
- **Irreversibility enforcement:** Simulation engine strictly implements `next_levers = max.(current_levers, target_levers)`
  - Prevents policies from accidentally "un-building" infrastructure
  - Enforced at physics level, not policy level
- **Discounting moved out:** Simulation returns raw undiscounted flows
  - Rationale 1 (Didactic): Students need to see actual catastrophic Year 50 damages, not tiny discounted values
  - Rationale 2 (Flexibility): Re-analyze same simulation with different discount rates (0% vs 3%) without re-running
  - Apply discounting only in objective function or post-processing
- Use Powell framework: policy(state, world) → action → transition → objective
- Dispatch on `(state, forcing)` pairs for mode-specific logic
- Marginal investment cost: `max(0, cost_new - cost_old)` (never charge for existing infrastructure)

**Testing Strategy:**

- Validate each mode independently
- Critical regression test: static policy convergence between modes
- Verify irreversibility across all scenarios
- Verify raw flows are NOT discounted
- Check trace completeness and accuracy

### Phase 8: Policies

**Goal:** Document policy interface and validate StaticPolicy implementation.

**Policy Parameterization (Powell Framework):**

Policies are parameterized as $\pi = (f, \theta)$ where:

- $f \in \mathcal{F}$ is the policy **type** (e.g., `StaticPolicy`, `ThresholdPolicy`)
- $\theta \in \Theta^f$ are the tunable **parameters** for that type

**Julia Implementation:**

- Policies are **callable structs**: `(policy)(state, forcing, year) -> Levers`
- `parameters(policy) -> AbstractVector{T}` extracts $\theta$ for optimization
- `PolicyType(θ::AbstractVector)` reconstructs policy from parameters
- Optimization searches over $\theta$ for a fixed policy type $f$

**Deliverables (Current Phase):**

- [ ] Documentation of policy design patterns in `src/policies.jl`
- [ ] Validation that StaticPolicy works correctly in both modes
- [ ] Example parameter round-trip: `policy == PolicyType(parameters(policy))`
- [ ] `docs/notebooks/phase8_policies.qmd` - Quarto notebook illustrating Phase 8 features

**Note:** StaticPolicy was implemented in Phase 2. Adaptive policy types (threshold, PID, rule-based, ML) are deferred to future work based on user needs.

### Phase 9: Optimization

**Goal:** Simulation-optimization interface using Metaheuristics.jl (NSGA-II).

**Approach (Powell Framework):**

This is **simulation-optimization**: we approximate the expectation in the objective function

$$\max_{\theta} \mathbb{E}\left\{\sum_{t=0}^{T} C(S_t, X^\pi(S_t), W_{t+1}) \mid S_0\right\}$$

by Monte Carlo sampling over pre-generated ensembles.

**Workflow:**

1. **Generate ensemble:** Create set of `(CityParameters, Forcing)` pairs representing uncertainty
2. **Evaluate policy:** For candidate $\theta$, simulate across ensemble members
3. **Aggregate:** Compute objective as aggregation over ensemble (mean, percentile, CVaR, etc.)
4. **Search:** Use metaheuristics to search over $\theta$ space

**Open Questions:**

1. **Lever bounds:** What are sensible default upper bounds for each lever? Should they scale with city parameters?
2. **Aggregation methods:** Which ensemble aggregations to support (mean, worst-case, CVaR, regret)?

**Deliverables:**

- [ ] `src/optimization.jl`:
  - `create_objective_function(ensemble; aggregation)` - Returns $f(\theta) \to [\text{cost}, \text{damage}]$
  - `optimize_policy(PolicyType, ensemble; n_gen, pop_size, seed)` - NSGA-II over $\theta$
  - `optimize_single_lever(ensemble, lever_index)` - Van Dantzig emulation
  - `OptimizationResult` struct for storing Pareto front and solutions
  - **Ensemble type:** `Vector{Tuple{CityParameters, Forcing}}` or similar

- [ ] Tests covering:
  - Single-member ensemble (deterministic case)
  - Multi-member ensemble aggregation
  - Pareto front non-domination
  - Cost-damage tradeoff (negative correlation)
  - Constraint handling (infeasible solutions rejected)
  - Single-lever optimization (regression test)
- [ ] `docs/notebooks/phase9_optimization.qmd` - Quarto notebook illustrating Phase 9 features

**Key Implementation Notes:**

- **Simulation-optimization:** Each $f(\theta)$ call runs `simulate()` for all ensemble members
- **Policy reconstruction:** $\theta \to$ `PolicyType(θ)` $\to$ `simulate(city, policy, forcing)`
- EAD mode preferred for speed (single integration vs many surge realizations)
- Constraint violations return `[Inf, Inf]`
- Bounds: $\theta$ bounds depend on policy type (for StaticPolicy: lever bounds)
- Use fixed random seed for reproducibility in tests

**Performance Expectations:**

- EAD mode: ~1ms per policy × ensemble member
- 100 ensemble members × 100 generations × 100 population = ~10⁶ simulations
- Target: < 1 hour for full optimization run

### Phase 10: Analysis & Data

**Goal:** Forward mode analysis with rich scenario outputs.

**Open Questions:**

1. **Array structure:** Should core outputs use (Time × Scenario × Variable) or different dimension ordering for better performance/usability?
2. **Summary statistics:** Which percentiles and statistics are most useful (10/50/90, 5/25/75/95, other)?
3. **Robustness metrics:** Which metrics best capture robustness for decision-making (regret, variance, CVaR, maximin)?

**Deliverables:**

- [ ] `src/surges.jl` - Surge scenario generation:
  - `generate_surge_scenarios(city, n_scenarios; gev_params, trend)` - Non-stationary GEV
  - `generate_constant_surges(city, height)` - Testing utility

- [ ] `src/analysis.jl` - Analysis functions:
  - `run_forward_mode(city, policy, surge_matrix)` - Returns standard Julia Array or NamedTuple (Time × Scenario × Variable)
  - `summarize_results(results)` - Percentiles and statistics (DataFrames output)
  - `calculate_robustness_metrics(optimization_result, surge_matrix, city)` - Robustness analysis
  - **Output format:** Use standard Julia Arrays/NamedTuples, NOT YAXArrays in core

- [ ] `ext/` or separate module (optional):
  - YAXArrays conversion utilities (if user has YAXArrays.jl installed)
  - Visualization helpers (optional package extension)
  - Heavy dependencies decoupled from core model

- [ ] Tests covering:
  - Surge generation (correct distributions, trends)
  - Forward mode array structure
  - Summary statistics
  - Robustness metrics calculation
- [ ] `docs/notebooks/phase10_analysis.qmd` - Quarto notebook illustrating Phase 10 features

**Key Implementation Notes:**

- **Core outputs:** Standard Julia Arrays/NamedTuples only (lightweight)
- **YAXArrays decoupled:** Move to package extension or separate analysis scripts
  - Avoids forcing heavy dependency on users who only run optimization
  - Users can opt-in to YAXArrays for advanced visualization
- Forward mode primarily uses stochastic forcing (detailed trajectories)
- Variables: investment, damage, W, R, P, D, B, surge (undiscounted raw flows)
- EAD mode for quick scenario screening (single run per scenario)
- Robustness metrics: p90 damage, max damage, regret, variance

**Analysis Workflow:**

1. Generate large surge ensemble (5000+ scenarios)
2. Optimize using EAD mode (fast)
3. Evaluate Pareto solutions using stochastic mode (detailed)
4. Analyze robustness and distributional properties
5. Optionally convert to YAXArrays for visualization (user choice)

## Package Structure

```
ICOW.jl/
├── Project.toml
├── README.md
├── LICENSE
├── ROADMAP.md (this file)
├── CLAUDE.md
├── PROGRESS.md
├── docs/
│   ├── simulation_modes.md    # Dual-mode documentation
│   ├── equations.md            # All equations from paper
│   ├── parameters.md           # Parameter documentation
│   ├── zones.md               # Zone structure documentation
│   └── figures/
├── src/
│   ├── ICOW.jl                # Main module file
│   ├── types.jl               # Abstract types, Levers
│   ├── parameters.jl          # CityParameters (concrete scalars)
│   ├── forcing.jl             # Forcing types (Stochastic/Distributional, ModelClock)
│   ├── states.jl              # State types (Stochastic/EAD)
│   ├── policies.jl            # Policy interface
│   ├── geometry.jl            # Dike volume (Equation 6)
│   ├── costs.jl               # Investment costs with bounds checking
│   ├── damage.jl              # Event and EAD damage
│   ├── zones.jl               # Fixed-size zone structure (5 zones)
│   ├── simulation.jl          # Unified simulation with dispatch (returns raw flows)
│   ├── objectives.jl          # Discounting and objective functions
│   ├── optimization.jl        # NSGA-II interface
│   ├── analysis.jl            # Forward mode (standard Arrays/NamedTuples)
│   └── surges.jl              # Surge generation
├── ext/                       # Optional package extensions
│   └── YAXArraysExt.jl       # YAXArrays conversion (optional)
└── test/
    ├── runtests.jl
    ├── parameters_tests.jl
    ├── types_tests.jl
    ├── type_system_tests.jl
    ├── forcing_tests.jl
    ├── geometry_tests.jl
    ├── costs_tests.jl
    ├── damage_tests.jl
    ├── damage_ead_tests.jl
    ├── zones_tests.jl
    ├── simulation_tests.jl
    ├── optimization_tests.jl
    └── analysis_tests.jl
```

## Implementation Checklist

### Phase 1: Parameters & Validation

- [x] Create `src/parameters.jl` with `CityParameters{T}`
- [x] Create `src/types.jl` with `Levers{T}` and constraints
- [x] Create `docs/parameters.md`
- [x] Write unit tests for parameter validation
- [x] Write unit tests for lever constraints
- [x] Create `docs/notebooks/phase1_parameters.qmd`

### Phase 2: Type System and Mode Design

- [ ] Create `docs/simulation_modes.md`
- [ ] Define abstract type hierarchy and `AbstractForcing` interface in `src/types.jl`
- [ ] Create `src/forcing.jl` with both forcing types and ModelClock
- [ ] Create `src/states.jl` with both state types
- [ ] Update `src/policies.jl` with policy interface and StaticPolicy
- [ ] Parameterize `CityParameters{T}` (concrete scalar fields only)
- [ ] Write comprehensive type system tests
- [ ] Verify type stability
- [ ] **USER REVIEW CHECKPOINT**

### Phase 3: Geometry

- [ ] Extract Equation 6 to `docs/equations.md`
- [ ] Implement `calculate_dike_volume()` in `src/geometry.jl` (exact, no decomposition)
- [ ] Validate against trapezoidal approximation
- [ ] Write geometry tests

### Phase 4: Core Physics - Costs and Event Damage

- [ ] Complete `docs/equations.md` with all equations (1-9)
- [ ] Implement cost functions in `src/costs.jl` with bounds checking (P < 1.0)
- [ ] Implement event damage in `src/damage.jl`
- [ ] Write comprehensive physics tests including boundary safety

### Phase 5: Expected Annual Damage

- [ ] Implement `calculate_expected_damage()` in `src/damage.jl`
- [ ] Support Monte Carlo and quadrature integration
- [ ] Test convergence between modes
- [ ] Test integration methods

### Phase 6: Zones

- [ ] Create `docs/zones.md` from paper Figure 3
- [ ] Implement fixed-size zone structure (5 zones) in `src/zones.jl`
- [ ] Update damage calculation for full zone model
- [ ] Write zone and full damage tests (including empty zone handling)

### Phase 7: Simulation Engine

- [ ] Implement unified `simulate()` with dispatch in `src/simulation.jl`
- [ ] Return raw undiscounted flows (costs and damages by year)
- [ ] Implement policy target + irreversibility enforcement
- [ ] Create `src/objectives.jl` for discounting and objective functions
- [ ] Test both modes independently
- [ ] Test mode convergence (critical regression)
- [ ] Test irreversibility and raw flow outputs

### Phase 8: Policies

- [ ] StaticPolicy (implemented in Phase 2)
- [ ] Document policy design patterns (callable structs, `parameters()`, reconstruction)
- [ ] Validate StaticPolicy works in both modes
- [ ] Test parameter round-trip: `policy == PolicyType(parameters(policy))`

### Phase 9: Optimization

- [ ] Implement `create_objective_function(ensemble; aggregation)` in `src/optimization.jl`
- [ ] Implement `optimize_policy(PolicyType, ensemble)` using NSGA-II
- [ ] Implement `optimize_single_lever()` for Van Dantzig emulation
- [ ] Test single-member and multi-member ensemble optimization
- [ ] Validate Pareto fronts and aggregation methods

### Phase 10: Analysis

- [ ] Implement surge generation in `src/surges.jl`
- [ ] Implement `run_forward_mode()` returning standard Arrays/NamedTuples in `src/analysis.jl`
- [ ] Implement analysis and robustness functions
- [ ] (Optional) Create `ext/YAXArraysExt.jl` for YAXArrays conversion
- [ ] Write analysis tests

### Documentation & Release

- [ ] Complete all `docs/*.md` files
- [ ] Write `README.md` with examples showing both modes
- [ ] Add GPLv3 `LICENSE` file
- [ ] Create example notebooks
- [ ] Run full test suite
- [ ] Profile performance (both modes)
- [ ] Tag v0.1.0 release
