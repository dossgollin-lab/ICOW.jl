# Phase 7: Simulation Engine

**Status:** ✅ Approved (with minor documentation recommendations)

**Prerequisites:** Phase 6 (Zones & City Characterization)

## Goal

Unified time-stepping simulation with dispatch on forcing/state types.

## Open Questions

1. **Error handling strategy:** How should we handle simulation failures mid-run (numerical errors, constraint violations)?
2. **Trace content:** What variables beyond [year, investment, damage, W, R, P, D, B] should be tracked?

## Deliverables

- [x] `src/simulation.jl` - Core simulation engine:
  - `simulate(city, policy, forcing; mode)` - Main simulation function
  - `initialize_state(forcing)` - Dispatch: StochasticForcing $\to$ StochasticState, etc.
  - `calculate_annual_damage(city, levers, state, forcing, year)` - Dispatch on mode
  - `update_state(state, levers, damage, forcing, year)` - Dispatch on mode
  - Helper functions for trace recording and result finalization
  - **Critical:** Irreversibility enforcement: `effective_levers = max(target_levers, current_levers)`
  - **Critical:** Return RAW, UNDISCOUNTED flows (costs and damages by year)

- [x] `src/objectives.jl` or similar - Post-processing functions:
  - `apply_discounting(flows, discount_rate)` - Apply discount factors to raw flows
  - Objective function wrappers that discount results from simulate()

- [x] Tests covering:
  - Both simulation modes (stochastic and EAD)
  - Scalar mode (optimization) vs trace mode (analysis)
  - Irreversibility enforcement (protection levels never decrease)
  - **Raw flows returned without discounting**
  - State updates and accumulation
  - Lightweight mode consistency check (both modes run without error on same inputs)

- [ ] Validation script or notebook (not unit test - too compute expensive) - **Deferred to Phase 10**:
  - Mode convergence: static policy EAD $\approx$ mean(1000+ stochastic scenarios)
  - Demonstrates Law of Large Numbers convergence
  - Documents expected tolerance and convergence rate

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
- Verify irreversibility across all scenarios
- Verify raw flows are NOT discounted
- Check trace completeness and accuracy
- Lightweight smoke test: both modes run successfully on same inputs
- **Full convergence validation in separate script** (too expensive for unit tests)

## Implementation Notes

**API Simplifications:** The implementation simplified the planned API by:
- Inlining `initialize_state()` (states constructed directly in simulation loop)
- Inlining `calculate_annual_damage()` (logic integrated into mode-specific implementations)
- Making `update_state()` private as `_update_state!()` (not part of public API)

These changes reduce abstraction layers and improve code clarity per project guidelines.

**Error Handling:** Added `safe` mode (try-catch wrapper) for optimization use cases. Returns `(Inf, Inf)` on simulation failures to gracefully handle infeasible policies during search.

**Critical Bug Fixed:** Double effective surge conversion in stochastic mode caused 75% damage underestimation. Fixed by passing raw surge to `calculate_event_damage_stochastic()` instead of pre-converted effective surge. See `docs/bugfixes.md` for details.

**Audit Results:** See `tasks/phase_7_audit.md` for detailed review.
- Rating: 4.5/5
- Core implementation approved
- Critical bug found and fixed during convergence validation
- Mode convergence validated: both modes agree within 1-3% for static policies
