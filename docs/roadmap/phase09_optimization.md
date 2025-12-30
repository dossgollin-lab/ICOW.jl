# Phase 9: Optimization

**Status:** Pending

**Prerequisites:** Phase 8 (Policies)

## Goal

Simulation-optimization interface using Metaheuristics.jl (NSGA-II).

## Approach (Powell Framework)

This is **simulation-optimization**: we approximate the expectation in the objective function

$$\max_{\theta} \mathbb{E}\left\{\sum_{t=0}^{T} C(S_t, X^\pi(S_t), W_{t+1}) \mid S_0\right\}$$

by Monte Carlo sampling over pre-generated ensembles.

### Workflow

1. **Generate ensemble:** Create set of `(CityParameters, Forcing)` pairs representing uncertainty
2. **Evaluate policy:** For candidate $\theta$, simulate across ensemble members
3. **Aggregate:** Compute objective as aggregation over ensemble (mean, percentile, CVaR, etc.)
4. **Search:** Use metaheuristics to search over $\theta$ space

## Open Questions

1. **Lever bounds:** What are sensible default upper bounds for each lever? Should they scale with city parameters?
2. **Aggregation methods:** Which ensemble aggregations to support (mean, worst-case, CVaR, regret)?

## Deliverables

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

## Key Design Decisions

- **Simulation-optimization:** Each $f(\theta)$ call runs `simulate()` for all ensemble members
- **Policy reconstruction:** $\theta \to$ `PolicyType(θ)` $\to$ `simulate(city, policy, forcing)`
- EAD mode preferred for speed (single integration vs many surge realizations)
- Constraint violations return `[Inf, Inf]`
- Bounds: $\theta$ bounds depend on policy type (for StaticPolicy: lever bounds)
- Use fixed random seed for reproducibility in tests

## Performance Expectations

- EAD mode: ~1ms per policy $\times$ ensemble member
- 100 ensemble members $\times$ 100 generations $\times$ 100 population = ~$10^6$ simulations
- Target: < 1 hour for full optimization run
