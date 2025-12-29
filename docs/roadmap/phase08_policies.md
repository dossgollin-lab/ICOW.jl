# Phase 8: Policies

**Status:** Pending

**Prerequisites:** Phase 7 (Simulation Engine)

## Goal

Document policy interface and validate StaticPolicy implementation.

## Policy Parameterization (Powell Framework)

Policies are parameterized as $\pi = (f, \theta)$ where:

- $f \in \mathcal{F}$ is the policy **type** (e.g., `StaticPolicy`, `ThresholdPolicy`)
- $\theta \in \Theta^f$ are the tunable **parameters** for that type

## Julia Implementation

- Policies are **callable structs**: `(policy)(state, forcing, year) -> Levers`
- `parameters(policy) -> AbstractVector{T}` extracts $\theta$ for optimization
- `PolicyType(θ::AbstractVector)` reconstructs policy from parameters
- Optimization searches over $\theta$ for a fixed policy type $f$

## Deliverables

- [ ] Documentation of policy design patterns in `src/policies.jl`
- [ ] Validation that StaticPolicy works correctly in both modes
- [ ] Example parameter round-trip: `policy == PolicyType(parameters(policy))`
- [ ] `docs/notebooks/phase8_policies.qmd` - Quarto notebook illustrating Phase 8 features

## Implementation Notes

**Note:** StaticPolicy was implemented in Phase 2. Adaptive policy types (threshold, PID, rule-based, ML) are deferred to future work based on user needs.
