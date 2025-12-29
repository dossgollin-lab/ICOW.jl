# Phase 7: Simulation Engine

**Status:** Pending

**Prerequisites:** Phase 6 (Zones & City Characterization)

## Goal

Unified time-stepping simulation with dispatch on forcing/state types.

## Open Questions

1. **Error handling strategy:** How should we handle simulation failures mid-run (numerical errors, constraint violations)?
2. **Trace content:** What variables beyond [year, investment, damage, W, R, P, D, B] should be tracked?

## Deliverables

- [ ] `src/simulation.jl` - Core simulation engine:
  - `simulate(city, policy, forcing; mode)` - Main simulation function
  - `initialize_state(forcing)` - Dispatch: StochasticForcing $\to$ StochasticState, etc.
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
  - Mode convergence (static policy: EAD $\approx$ mean(stochastic))
  - State updates and accumulation

- [ ] `docs/notebooks/phase7_simulation.qmd` - Quarto notebook illustrating Phase 7 features

## Key Design Decisions

- **Policy interface:** Policies return TARGET lever state, not final decision
- **Irreversibility enforcement:** Simulation engine strictly implements `next_levers = max.(current_levers, target_levers)`
  - Prevents policies from accidentally "un-building" infrastructure
  - Enforced at physics level, not policy level
- **Discounting moved out:** Simulation returns raw undiscounted flows
  - Rationale 1 (Didactic): Students need to see actual catastrophic Year 50 damages, not tiny discounted values
  - Rationale 2 (Flexibility): Re-analyze same simulation with different discount rates (0% vs 3%) without re-running
  - Apply discounting only in objective function or post-processing
- Use Powell framework: policy(state, world) $\to$ action $\to$ transition $\to$ objective
- Dispatch on `(state, forcing)` pairs for mode-specific logic
- Marginal investment cost: `max(0, cost_new - cost_old)` (never charge for existing infrastructure)

## Testing Strategy

- Validate each mode independently
- Critical regression test: static policy convergence between modes
- Verify irreversibility across all scenarios
- Verify raw flows are NOT discounted
- Check trace completeness and accuracy
