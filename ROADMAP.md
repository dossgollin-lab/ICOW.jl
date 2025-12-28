# iCOW.jl Implementation Roadmap

## Architecture Overview

Following Warren Powell's sequential decision framework:

```
┌──────────────────────────────────────────────────────────┐
│                  DECISION FRAMEWORK                       │
│                                                           │
│  Policy: (S_t, W_t) → x_t                                │
│    where S_t = SimulationState (endogenous)              │
│          W_t = WorldState (exogenous)                    │
│          x_t = Levers (action)                           │
│                                                           │
│  Transition: S_{t+1} = f(S_t, x_t, W_{t+1})             │
│  Simulation: Run policy over SOW trajectory              │
│  Optimization: Search over policy parameters             │
│                                                           │
└─────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│               CORE SYSTEM MODEL                           │
│                                                           │
│  Pure functions implementing physics & economics:         │
│    Levers → Costs (Eqs 1,3-5,7)                          │
│    Levers + Surge → Damage (Eqs 8-9)                     │
│                                                           │
│  No state, no time, no decisions                         │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

**Core System Model:** Pure functions mapping (Levers, Surge) → (Cost, Damage)
**Decision Framework:** Sequential decisions under uncertainty (Powell framework)

## Phase 1: Core System Model

**Goal:** Implement Equations 1-9 as pure functions.

All files in `src/` (flat structure for now).

### Phase 1a: Foundation & Geometry

**Files:** `src/types.jl`, `src/geometry.jl`

**Types:**

- `CityParameters{T<:Real}` - All exogenous parameters from equations.md
- `Levers{T<:Real}` - The 5 decision levers (W, R, P, D, B) with constraint validation

**Functions:**

```julia
calculate_dike_volume(city::CityParameters, D::Real, B::Real) → Float64
```

**Implementation:**

- Equation 6 from paper (page 17)
- Use paper formula, NOT C++ code (has bug on line 145)
- See equations.md for exact formula

**Tests:**

- Type construction and validation
- Zero height → zero volume
- Monotonicity in D
- Numerical stability

**Deliverable:** `types.jl` and `geometry.jl` with passing tests

### Phase 1b: Costs

**File:** `src/costs.jl`

**Functions:**

```julia
calculate_withdrawal_cost(city::CityParameters, W::Real) → Float64  # Eq 1
calculate_value_after_withdrawal(city::CityParameters, W::Real) → Float64  # Eq 2
calculate_resistance_cost_fraction(city::CityParameters, P::Real) → Float64  # Eq 3
calculate_resistance_cost(city::CityParameters, levers::Levers) → Float64  # Eqs 4-5
calculate_dike_cost(city::CityParameters, D::Real, B::Real) → Float64  # Eq 7
calculate_investment_cost(city::CityParameters, levers::Levers) → Float64  # Sum
```

**Implementation notes:**

- Eq 3: Include f_adj = 1.25, use code parameters (f_exp=0.115, t_exp=0.4)
- Eqs 4-5: Select formula based on R vs B

**Tests:**

- Zero inputs → zero costs
- Monotonicity: increasing lever → increasing cost
- Component sum: total = withdrawal + resistance + dike

**Deliverable:** `costs.jl` with passing tests

### Phase 1c: Damage & Zones

**File:** `src/damage.jl`

**Functions:**

```julia
calculate_effective_surge(surge::Real, city::CityParameters) → Float64
calculate_dike_failure_probability(surge::Real, D::Real, t_fail::Real, p_min::Real) → Float64  # Eq 8
calculate_zone_values(city::CityParameters, levers::Levers) → NTuple{5,Float64}
calculate_event_damage(city::CityParameters, levers::Levers, surge::Real; dike_failed::Bool) → Float64  # Eq 9
```

**Implementation:**

- Zone-by-zone damage calculation
- Eq 8: Use corrected piecewise form from equations.md
- Include seawall, wave runup, threshold damage
- Dike failure is stochastic (Bernoulli draw in simulation, deterministic flag here)

**Zone structure:**

- Zone 0: Withdrawn (0 to W)
- Zone 1: Resistant (W to min(W+R, B))
- Zone 2: Unprotected gap (min(W+R, B) to B) - only if R < B
- Zone 3: Dike protected (B to B+D)
- Zone 4: Above dike (B+D to H_city)

**Tests:**

- No damage below seawall
- Monotonicity in surge
- Resistance reduces damage
- Dike protection works
- Failed dike increases damage

**Deliverable:** `damage.jl` with passing tests

**Phase 1 Complete:** Core system model ready

```julia
# User can now do:
city = CityParameters()
levers = Levers(W=0.0, R=3.0, P=0.5, D=5.0, B=2.0)

cost = calculate_investment_cost(city, levers)
damage = calculate_event_damage(city, levers, 3.5; dike_failed=false)
```

## Phase 2: Simulation Framework

**Goal:** Time-stepping simulation following Powell's sequential decision framework.

### Phase 2a: State & World

**File:** `src/simulation.jl`

**Context separation:**

| Container | Contents | Changes during sim? |
|-----------|----------|---------------------|
| `city` (CityParameters) | Physical/economic constants | No - fixed context |
| `state` (SimulationState) | What we control: levers, accumulated cost/damage | Yes - updated by decisions |
| `world` (WorldState) | External conditions: surge, SLR | Yes - evolves exogenously |

**Types:**

```julia
# S_t - Endogenous system state (what we control/track)
mutable struct SimulationState{T<:Real}
    year::Int
    current_levers::Levers{T}
    accumulated_cost::T
    accumulated_damage::T
end

# W_t - Exogenous information (external, given)
struct WorldState{T<:Real}
    year::Int
    slr::T           # Sea level rise at this time (m)
    surge::T         # This year's surge realization (m)
end
```

### Phase 2b: Policy Interface

**File:** `src/policies.jl`

**Interface (callable objects):**

```julia
abstract type AbstractPolicy end

# Policy function: x_t = π(S_t, W_t) → target Levers
(policy::AbstractPolicy)(state::SimulationState, world::WorldState) → Levers
```

**Implementations:**

- `StaticPolicy` - Build target configuration at t=1, do nothing after
- `ThresholdPolicy` - Adapt based on surge history

### Phase 2c: Simulation Engine

**File:** `src/simulation.jl` (continued)

**Core structure:**

```julia
state = setup_simulation(city, policy, ...)

for t in 1:T
    world = get_world(t, surges[t], ...)
    action = policy(state, world)
    state = step!(state, city, world, action)
    # optionally record to trace
end

return finalize(state)
```

**Functions:**

- `setup_simulation(city, ...)` - Initialize state
- `step!(state, city, world, action)` - Single timestep (core physics)
- `simulate(city, policy, surges)` - Full run, returns (cost, damage)
- `simulate_trace(city, policy, surges)` - Full run, returns DataFrame with history

**Key features:**

- **Irreversibility:** `new_levers = max(old_levers, policy_levers)` enforced in `step!` as a safety constraint.
  Rationale: infrastructure investments can't be undone (dikes can't shrink, floodproofing can't be removed).
- **Marginal costs:** `max(0, cost_new - cost_old)` - only pay for new investment
- **Discounting:** Applied per timestep

**Design decisions to resolve before Phase 2:**

- How should surge history be tracked for adaptive policies (e.g., ThresholdPolicy)?
- How is SLR represented and how does it affect surge/damage calculations?
- What is the discount rate and how is it applied?
- What is the simulation time horizon and timestep?

**Phase 2 Complete:** Working simulation

```julia
policy = StaticPolicy(Levers(W=0.0, R=3.0, P=0.5, D=5.0, B=2.0))
result = simulate(city, policy, surges)
trace = simulate_trace(city, policy, surges)
```

## Phase 3: Optimization

**Goal:** Multi-objective search over policy parameters.

**File:** `src/optimization.jl`

- Wrapper around Metaheuristics.jl
- Search over policy parameter space
- Return Pareto-optimal solutions

**Regression test:** Van Dantzig U-curve (dike-only optimization)

## Phase 4: Uncertainty & Scenarios

**Goal:** Define and sample states of the world.

**Design TBD:** The representation of deep uncertainty (what parameters vary, how they evolve) needs further thought before implementation.

Key questions to resolve:

- What parameters are deeply uncertain vs. well-characterized risk?
- How do surge distributions evolve over time?
- What is the ensemble sampling strategy?

## Phase 5: Analysis & Robustness

**Goal:** Tools for exploring policy performance across scenarios.

**File:** `src/analysis.jl`

- Forward mode: Full (Time × Scenario × Policy × Metric) arrays
- Robustness metrics across SOW ensemble
- Policy comparison tools

## Implementation Checklist

**Phase 1: Core System Model**

- [ ] 1a: types.jl - CityParameters, Levers with validation
- [ ] 1a: geometry.jl - Equation 6 (dike volume)
- [ ] 1b: costs.jl - Equations 1, 3-5, 7 (all costs)
- [ ] 1c: damage.jl - Equations 8-9 (damage calculation)
- [ ] Unit tests for all core functions

**Phase 2: Simulation Framework**

- [ ] 2a: State types - SimulationState, WorldState
- [ ] 2b: Policy interface - AbstractPolicy with callable
- [ ] 2c: Simulation engine - Time-stepping loop
- [ ] Integration tests

**Phase 3: Optimization**

- [ ] optimization.jl - Multi-objective search
- [ ] Regression test: Van Dantzig U-curve

**Phase 4: Uncertainty (Design TBD)**

- [ ] Define StateOfWorld representation
- [ ] Scenario generation

**Phase 5: Analysis**

- [ ] Forward mode simulation
- [ ] Robustness metrics

## File Structure

```text
ICOW.jl/
├── src/
│   ├── ICOW.jl            # Main module
│   ├── types.jl           # Phase 1a
│   ├── geometry.jl        # Phase 1a
│   ├── costs.jl           # Phase 1b
│   ├── damage.jl          # Phase 1c
│   ├── simulation.jl      # Phase 2
│   ├── policies.jl        # Phase 2
│   ├── optimization.jl    # Phase 3
│   └── analysis.jl        # Phase 5
├── test/
│   └── runtests.jl
└── docs/
    └── equations.md
```

## Workflow

After each phase:

1. **STOP** - run tests: `julia --project test/runtests.jl`
2. **REPORT** - what was implemented, any issues
3. **WAIT** - for approval before next phase

## Dependencies

Required packages (add as needed, ask permission first):

- Test (stdlib)
- Distributions (Phase 2/4)
- DataFrames (Phase 2)
- Metaheuristics (Phase 3)
- Statistics (stdlib)

**Current Status:** Ready to begin Phase 1a (types + geometry).
