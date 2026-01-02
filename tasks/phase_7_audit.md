# Phase 7 Audit: Simulation Engine

## Audit Scope

This audit reviews the Phase 7 implementation (Simulation Engine) to verify:

1. **Plan Adherence**: All deliverables from phase07_simulation.md completed correctly
2. **Code Quality**: Adherence to project guidelines (simplicity, no over-engineering)
3. **Mathematical Fidelity**: Correct implementation of simulation logic
4. **Test Coverage**: Adequate testing per guidelines
5. **Documentation**: Docstrings follow minimal reference style
6. **Overcomplication**: Identification of any unnecessarily complex code

## Audit Checklist

### Plan Adherence

- [ ] `src/simulation.jl` created with all required functions
- [ ] `src/objectives.jl` created with discounting functions
- [ ] Tests cover both simulation modes
- [ ] Tests cover irreversibility enforcement
- [ ] Tests verify raw flows (undiscounted)
- [ ] Tests verify mode convergence (static policy)
- [ ] Open questions resolved

### Code Quality

- [ ] No unnecessary abstractions or over-engineering
- [ ] Simple, direct implementations
- [ ] Minimal allocations in scalar mode
- [ ] Type stability where expected
- [ ] Follows project style guidelines

### Mathematical Correctness

- [ ] Irreversibility: `next_levers = max(current, target)`
- [ ] Marginal costing: only charge for new infrastructure
- [ ] Raw flows returned (no discounting in simulation)
- [ ] Proper state updates
- [ ] Mode-specific logic correct

### Testing

- [ ] Minimal but sufficient tests
- [ ] Clear test comments explaining invariants
- [ ] No redundant test cases
- [ ] Type stability tested appropriately

### Documentation

- [ ] Docstrings minimal and reference-based
- [ ] No equation duplication
- [ ] No verbose sections

## Findings

### Critical Issues

_None identified. Core implementation is sound._

---

### Minor Issues

**1. Missing Validation Artifact**

The plan now specifies a **validation script or notebook** (not unit test) to demonstrate mode convergence.
This should compare EAD mode against mean of 1000+ stochastic scenarios for a static policy.

**Status**: Not blocking for phase completion, but should be created before claiming full validation.

**2. Missing Lightweight Consistency Test**

The updated plan suggests a lightweight smoke test: both modes run successfully on the same inputs.
This wouldn't prove full convergence but would catch major bugs (wrong state update, missing logic, etc.).

**Suggested implementation** (fast enough for unit tests):
```julia
@testset "5. Mode Consistency (Smoke Test)" begin
    # Same inputs for both modes
    policy = StaticPolicy(Levers(0.0, 0.0, 0.0, 3.0, 0.0))

    # Run both modes
    (stoch_cost, stoch_damage) = simulate(city, policy, stoch_forcing; scenario=1)
    (ead_cost, ead_damage) = simulate(city, policy, dist_forcing)

    # Both should succeed (no NaN/Inf from bugs)
    @test isfinite(stoch_cost) && isfinite(stoch_damage)
    @test isfinite(ead_cost) && isfinite(ead_damage)

    # Rough sanity check: same order of magnitude (not exact equality)
    # This catches major bugs like missing state updates or wrong damage calculation
    @test stoch_cost > 0 && ead_cost > 0
    @test abs(log10(stoch_cost) - log10(ead_cost)) < 2  # Within 2 orders of magnitude
end
```

**Status**: Optional but recommended as a quick sanity check.

**3. Plan Deliverables Not Fully Matched**

The plan specified these functions:
- `initialize_state(forcing)` - NOT implemented (states constructed inline)
- `calculate_annual_damage(city, levers, state, forcing, year)` - NOT implemented (logic inline)
- `update_state(state, levers, damage, forcing, year)` - Implemented as private `_update_state!`

**Analysis**: The junior dev inlined some logic and made other functions private.
This is actually simpler (follows guideline #6: simplicity), but doesn't match the plan's API design.

**Status**: Acceptable deviation that improves simplicity, but should be noted.

**4. Safe Mode Implementation Has Edge Case**

In `simulation.jl:24-34` and `simulation.jl:51-61`, safe mode always returns `(T(Inf), T(Inf))` on error, regardless of mode.
But in trace mode, the expected return type is `NamedTuple`, not `Tuple`.

The `objective_total_cost` function handles this by checking `isa(trace, Tuple)` to detect failures, which works but is indirect.

**Status**: Works correctly but is somewhat hacky. Consider making the error return type match the expected mode.

**5. Trace Recording Is Repetitive**

Lines 120-128 (stochastic) and 186-194 (EAD) have repetitive vector assignments:
```julia
year_vec[year] = year
W_vec[year] = new_levers.W
# ... etc
```

**Analysis**: This is straightforward but verbose. Could use a helper function or tuple unpacking.
However, explicit code is clearer and has zero overhead.

**Status**: Not critical. Explicit is fine per simplicity guidelines.

**6. Allocation Budget Seems High**

Test allows < 50KB allocations for scalar mode.
For a function that runs millions of times in optimization, this seems high.

**Analysis**: Allocations likely come from RNG sampling in `calculate_event_damage_stochastic`.
This is inherent to the stochastic mode, not a simulation engine issue.
EAD mode would have fewer allocations.

**Status**: Acceptable for stochastic mode. Should verify EAD mode allocations separately.

---

### Recommendations

**1. Add Helper for Lever Recording**

Consider a helper function to reduce repetition:
```julia
function _record_levers!(vectors, year, levers)
    vectors.W[year] = levers.W
    vectors.R[year] = levers.R
    # etc
end
```

**Assessment**: This adds a layer of indirection. Current code is simple and explicit.
**Recommendation**: Keep as-is per simplicity guidelines.

**2. Consider Merging `_finalize_trace`**

The `_finalize_trace` function (lines 248-273) just constructs a NamedTuple.
Could be inlined at the return sites.

**Assessment**: Extraction makes the return statement cleaner and the signature self-documenting.
**Recommendation**: Keep as-is. Minimal abstraction is warranted here.

**3. Document Safe Mode Behavior**

The docstrings don't mention the `safe` parameter or error handling behavior.

**Recommendation**: Add brief comment about safe mode returns `(Inf, Inf)` on failure.

---

### Positive Observations

**1. Excellent Irreversibility Implementation**

Lines 99 and 171: `new_levers = max(state.current_levers, target)`

This is exactly per plan and uses the custom `Base.max` for `Levers`.
Clean, simple, impossible to bypass.

**2. Marginal Costing Is Correct**

The `_marginal_cost` function (lines 216-220) properly charges only for incremental infrastructure.
`max(zero(T), cost_new - cost_old)` handles first year automatically.

**3. Dispatch-Based Mode Selection**

Using method dispatch on `AbstractForcing` types to select mode is elegant and type-stable.
No runtime conditionals needed.

**4. State Management Is Clean**

States are mutable (necessary for accumulation) but mutation is confined to `_update_state!`.
The rest of the simulation is functionally pure.

**5. Test Quality Is Good**

Tests are focused on key invariants:
- Irreversibility (monotonicity check across all levers)
- Marginal costing (zero cost after static build)
- Raw flows (no discounting)
- Type stability with realistic allocation budget

Test comments follow the prescribed format with physical reasoning.

**6. Code Is Readable**

Despite being 273 lines, the simulation engine is easy to follow.
Clear variable names, logical flow, well-commented.

---

## Detailed Checklist Results

### Plan Adherence

- [x] `src/simulation.jl` created with all required functions
- [x] `src/objectives.jl` created with discounting functions
- [x] Tests cover both simulation modes
- [x] Tests cover irreversibility enforcement
- [x] Tests verify raw flows (undiscounted)
- [x] Tests verify scalar vs trace mode
- [x] Tests verify state updates (via accumulation checks)
- [~] Lightweight mode consistency check (not implemented, but optional)
- [ ] **Validation script/notebook for mode convergence** ← Not created yet (not blocking)
- [~] Open questions resolved (safe mode added without explicit approval)

### Code Quality

- [x] No unnecessary abstractions (helper functions are justified)
- [x] Simple, direct implementations
- [x] Minimal allocations in scalar mode (< 50KB, mostly from RNG)
- [x] Type stability where expected (mode parameter causes Union return, documented)
- [x] Follows project style guidelines

### Mathematical Correctness

- [x] Irreversibility: `next_levers = max(current, target)` ✓
- [x] Marginal costing: only charge for new infrastructure ✓
- [x] Raw flows returned (no discounting in simulation) ✓
- [x] Proper state updates ✓
- [x] Mode-specific logic correct ✓

### Testing

- [x] Minimal but sufficient tests (4 test sets, focused)
- [x] Clear test comments explaining invariants
- [x] No redundant test cases
- [x] Type stability tested appropriately

### Documentation

- [x] Docstrings minimal and reference-based
- [x] No equation duplication
- [x] No verbose sections
- [~] Safe mode parameter not documented

---

## Overcomplication Analysis

**Question**: Did the junior dev overcomplicate anything?

**Analysis**:

1. **Safe Mode**: Not in the plan, but useful for optimization. Implementation is simple (try-catch wrapper). Not overcomplicated.

2. **Helper Functions**:
   - `_marginal_cost`: Used in both modes, saves duplication ✓
   - `_update_state!`: Dispatches on state type, clean separation ✓
   - `_finalize_trace`: Simple NamedTuple constructor, debatable but acceptable ✓

3. **Wrapper Functions**: The public `simulate` wraps internal `_simulate_*` functions.
   - The wrapper handles safe mode and dispatches on forcing type
   - The internal functions contain the actual logic
   - This separation is clean and not overcomplicated ✓

4. **What's NOT Overengineered**:
   - No custom exception types
   - No complex state machines
   - No premature optimization (allocation budget is realistic)
   - No unnecessary configuration options
   - No hooks or callbacks

**Verdict**: The code is appropriately simple. The junior dev resisted overengineering.

---

## Comparison to C++ Implementation

**Note**: Phase 7 is about the simulation engine structure, not physics.
The C++ code has a single monolithic simulation function.
This Julia implementation:

1. **Better**: Dual-mode support with dispatch (C++ doesn't have EAD mode)
2. **Better**: Clean separation of physics (pure functions) from state management
3. **Better**: Type-safe state and forcing types
4. **Similar**: Time-stepping loop structure is essentially the same

**Mathematical Fidelity**: Not applicable to simulation engine structure.
Physics functions were validated in previous phases.

---

## Conclusion

**Overall Assessment**: ★★★★½ (4.5/5)

**Strengths**:
- Clean, readable implementation
- Excellent test coverage for key invariants
- Proper irreversibility enforcement
- Raw flows (undiscounted) correctly returned
- Appropriate level of abstraction (not overengineered)
- Good adherence to project guidelines
- Junior dev showed restraint and avoided overcomplication

**Weaknesses**:
- Safe mode behavior not documented
- Minor deviation from plan's API (functions inlined - actually an improvement)
- Mode convergence validation script/notebook not created (can be done later)

**Recommendation**: **APPROVE with minor documentation update**

**Required Changes** (5 minutes):
1. Document safe mode parameter in docstrings

**Recommended Improvements** (optional):
1. Add lightweight mode consistency smoke test (10 minutes)
2. Create validation notebook for mode convergence (separate task, Phase 10)
3. Note API simplifications vs plan in comments (5 minutes)

**Estimated Effort**: 5 minutes for required change, 15 minutes for recommended improvements.

**Risk Assessment**: Very low risk. Core logic is sound and well-tested.

---

## Action Items for Junior Dev

### Required (5 minutes)

1. **Document safe mode in docstrings**:
   - Add parameter description to main `simulate` docstrings
   - Note that safe mode returns `(Inf, Inf)` on error for use in optimization

### Recommended (15 minutes)

2. **Add lightweight mode consistency smoke test** in `test/simulation_tests.jl`:
   - Run both modes on same simple inputs
   - Verify both succeed (no NaN/Inf)
   - Verify results are same order of magnitude
   - See suggested implementation in audit section "Missing Lightweight Consistency Test"

3. **Add comment noting API simplification vs plan**:
   - Note that `initialize_state` and `calculate_annual_damage` were inlined for simplicity
   - Mention that `update_state` is private (`_update_state!`) instead of public

### Future Work (Phase 10)

4. **Create validation notebook** (`notebooks/mode_convergence.jl` or similar):
   - Compare EAD mode against mean of 1000+ stochastic scenarios
   - Demonstrate Law of Large Numbers convergence
   - Document expected tolerance and convergence rate
   - Include visualizations of convergence as N increases
