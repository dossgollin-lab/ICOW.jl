# Phase 12: Adaptive Policy Infrastructure

**Status:** Pending

**Prerequisites:** Phase 11 (SOW Architecture)

## Goal

Create infrastructure that makes it **easy to define new adaptive policies**.
Different policies need different observable information - the framework should be flexible enough to support any policy the user wants to define.

## Motivation

The current `State` struct only tracks `current_levers` and `current_year`.
Adaptive policies need access to observable information to make decisions:

| Example Policy | Observable Information Needed |
|----------------|------------------------------|
| Freeboard policy: "If MSL comes within FB of levee top, raise to MSL + FB + buffer" | Current SLR, current dike height |
| Damage trigger: "After damage exceeds threshold, increase resistance" | Damage history |
| Surge threshold: "After N surges above level X, raise dike" | Surge history |
| Budget-based: "Invest up to $X per decade" | Accumulated investment costs |

The infrastructure should make all of these easy to implement.

## Open Questions

1. **State granularity:** Should State track full history vectors, or just summary statistics (max surge, cumulative damage)?
2. **Memory vs computation:** Pre-compute and store everything, or compute on demand?
3. **Policy declaration:** Should policies declare what observables they need, or always receive everything?

## Deliverables

- [ ] Enhanced `State` struct with observable history:
  - `surge_history::Vector{T}` - Realized surges by year
  - `damage_history::Vector{T}` - Realized damages by year
  - `slr_history::Vector{T}` - Realized SLR by year (from forcing)
  - `investment_history::Vector{T}` - Investment costs by year
  - Accessor functions: `get_current_slr(state)`, `get_max_surge(state)`, etc.

- [ ] Updated simulation loop to populate State history:
  - Record surge, damage, investment each year
  - Pass updated State to policy each timestep

- [ ] Example adaptive policy implementation:
  - `FreeboardPolicy`: Maintain dike height at MSL + freeboard + buffer
  - Demonstrates how to access observables and make decisions

- [ ] Documentation:
  - How to define a new adaptive policy
  - What observables are available
  - Performance considerations (history length)

- [ ] Tests:
  - State history accumulation
  - Freeboard policy behavior under rising SLR
  - Policy decisions based on observable state

## Key Design Decisions

- **Backward compatible:** Static policies should work unchanged (ignore history fields)
- **Opt-in complexity:** Simple policies don't pay for history tracking they don't use
- **User-extensible:** Framework makes it easy for users to define their own policies
- **Stochastic mode required:** Adaptive policies only make sense with realized events (not EAD mode)

## Example: Freeboard Policy

```julia
struct FreeboardPolicy{T} <: AbstractPolicy{T}
    freeboard::T      # Minimum clearance above MSL
    buffer::T         # Additional height when raising
    initial_D::T      # Initial dike height
end

function (p::FreeboardPolicy)(state, forcing, year)
    current_slr = get_current_slr(state, forcing, year)
    current_D = state.current_levers.D

    # If MSL comes within freeboard of dike top, raise it
    if current_slr + p.freeboard > current_D
        new_D = current_slr + p.freeboard + p.buffer
        return Levers(0, 0, 0, 0, new_D)
    else
        return Levers(0, 0, 0, 0, 0)  # No change
    end
end
```

This is just one example - the infrastructure should make defining any policy this straightforward.
