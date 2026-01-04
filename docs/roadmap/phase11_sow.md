# Phase 11: SOW Architecture

**Status:** Pending

**Prerequisites:** Phase 10 (Analysis & Aggregation)

## Goal

Explicit representation of States of the World (SOW) with clear SLR trajectory objects and documented mode dispatch.

## Motivation

Currently, SLR is implicit in the evolution of surge distributions across years.
This works but makes it harder to:

- Reason about climate scenarios explicitly
- Share SOW definitions across analyses
- Validate that distributions evolve as expected

## Open Questions

1. **Trajectory representation:** Should SLR trajectories be functions `year -> slr` or discrete arrays?
2. **Scenario composition:** How should SLR trajectories combine with surge distribution parameters?
3. **Backwards compatibility:** Can we add trajectory objects without breaking existing forcing types?

## Deliverables

- [ ] Explicit SLR trajectory types:
  - `SLRTrajectory` struct or function interface
  - Factory functions for common scenarios (linear, exponential, etc.)
  - Integration with existing forcing types

- [ ] Mode dispatch documentation:
  - Document that simulation mode is selected implicitly by forcing type
  - `StochasticForcing` $\to$ stochastic mode (samples realized surges)
  - `DistributionalForcing` $\to$ EAD mode (integrates over surge distribution)
  - Add this to `docs/framework.md` and/or docstrings

- [ ] Tests covering:
  - SLR trajectory construction and evaluation
  - Forcing construction from trajectories
  - Mode dispatch behavior validation

## Key Design Decisions

- **Minimal disruption:** New types should compose with existing forcing types, not replace them
- **Optional adoption:** Users can continue using current approach if preferred
- **Clear documentation:** Mode dispatch should be obvious to new users
