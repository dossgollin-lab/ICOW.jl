# Phase 10: Analysis & Data

**Status:** Pending

**Prerequisites:** Phase 9 (Optimization)

## Goal

Forward mode analysis with rich scenario outputs.

## Open Questions

1. **Array structure:** Should core outputs use (Time $\times$ Scenario $\times$ Variable) or different dimension ordering for better performance/usability?
2. **Summary statistics:** Which percentiles and statistics are most useful (10/50/90, 5/25/75/95, other)?
3. **Robustness metrics:** Which metrics best capture robustness for decision-making (regret, variance, CVaR, maximin)?

## Deliverables

- [ ] `src/surges.jl` - Surge scenario generation:
  - `generate_surge_scenarios(city, n_scenarios; gev_params, trend)` - Non-stationary GEV
  - `generate_constant_surges(city, height)` - Testing utility

- [ ] `src/analysis.jl` - Analysis functions:
  - `run_forward_mode(city, policy, surge_matrix)` - Returns standard Julia Array or NamedTuple (Time $\times$ Scenario $\times$ Variable)
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

## Key Design Decisions

- **Core outputs:** Standard Julia Arrays/NamedTuples only (lightweight)
- **YAXArrays decoupled:** Move to package extension or separate analysis scripts
  - Avoids forcing heavy dependency on users who only run optimization
  - Users can opt-in to YAXArrays for advanced visualization
- Forward mode primarily uses stochastic forcing (detailed trajectories)
- Variables: investment, damage, W, R, P, D, B, surge (undiscounted raw flows)
- EAD mode for quick scenario screening (single run per scenario)
- Robustness metrics: p90 damage, max damage, regret, variance

## Analysis Workflow

1. Generate large surge ensemble (5000+ scenarios)
2. Optimize using EAD mode (fast)
3. Evaluate Pareto solutions using stochastic mode (detailed)
4. Analyze robustness and distributional properties
5. Optionally convert to YAXArrays for visualization (user choice)
