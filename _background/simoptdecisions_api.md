# SimOptDecisions API Reference

Quick reference for implementing SimOptDecisions integration in ICOW.
For full documentation, see the SimOptDecisions package source.

## Abstract Types (User Subtypes These)

```julia
abstract type AbstractConfig end     # Model configuration (wraps CityParameters)
abstract type AbstractScenario end   # External forcing (surge time series or distributions)
abstract type AbstractState end      # Simulation state (current protection levels)
abstract type AbstractPolicy end     # Decision rule (maps state → action)
abstract type AbstractOutcome end    # Simulation result (investment + damage)
abstract type AbstractAction end     # Optional: explicit action type
```

## Required Callbacks (User Implements These)

Five callbacks define the simulation loop:

```julia
# 1. Create initial state
SimOptDecisions.initialize(config::MyConfig, scenario::MyScenario, rng::AbstractRNG) -> MyState

# 2. Define time points (must have length())
SimOptDecisions.time_axis(config::MyConfig, scenario::MyScenario) -> 1:n_years

# 3. Map state to action (called each timestep)
SimOptDecisions.get_action(policy::MyPolicy, state::MyState, t::TimeStep, scenario::MyScenario) -> action

# 4. Execute one timestep (called each timestep)
SimOptDecisions.run_timestep(state::MyState, action, t::TimeStep, config::MyConfig, scenario::MyScenario, rng::AbstractRNG) -> (new_state, step_record)

# 5. Aggregate results
SimOptDecisions.compute_outcome(step_records::Vector, config::MyConfig, scenario::MyScenario) -> MyOutcome
```

## TimeStep

```julia
struct TimeStep{V}
    t::Int   # 1-based index
    val::V   # Actual time value (year, date, etc.)
end

index(t::TimeStep) -> Int    # Get the index
value(t::TimeStep) -> V      # Get the value
```

## Policy Interface (For Optimization)

```julia
# Extract parameters as vector (for optimizer)
SimOptDecisions.params(policy::MyPolicy) -> Vector{Float64}

# Return bounds for each parameter
SimOptDecisions.param_bounds(::Type{MyPolicy}) -> Vector{Tuple{Float64, Float64}}
```

## Running Simulations

```julia
# Single simulation
outcome = simulate(config, scenario, policy)
outcome = simulate(config, scenario, policy, rng)

# With tracing (records state/action history)
outcome, trace = simulate_traced(config, scenario, policy)
```

## Optimization

```julia
# Define objectives
objectives = [minimize(:total_cost), maximize(:protection)]

# Run optimization
result = optimize(
    config,
    scenarios,           # Vector of scenarios
    MyPolicy,            # Policy type (not instance)
    objectives;
    backend = MetaheuristicsBackend(algorithm=:NSGA2),
    batch_size = FullBatch(),
)

# Access Pareto front
for (params, obj_values) in pareto_front(result)
    policy = MyPolicy(params)  # Reconstruct policy from parameters
end
```

## Utility Functions

```julia
discount_factor(rate, t)     # (1 + rate)^(-t)
is_first(t::TimeStep)        # t.t == 1
is_last(t::TimeStep, n)      # t.t == n
```

## ICOW Implementation

See `src/ICOW.jl` and `src/simulation.jl` for the full implementation.

**Types (subtype SimOptDecisions abstracts):**

```julia
struct Config <: AbstractConfig ... end
struct Scenario <: AbstractScenario ... end
mutable struct State <: AbstractState
    defenses::FloodDefenses{Float64}
end
struct StaticPolicy{T<:Real} <: AbstractPolicy
    W::T; R::T; P::T; D::T; B::T
end
struct Outcome <: AbstractOutcome ... end
```

**SimOptDecisions methods (in simulation.jl):**

```julia
SimOptDecisions.initialize(config::Config, scenario::Scenario, rng) = State()
SimOptDecisions.time_axis(config::Config, scenario::Scenario) = 1:length(scenario.surges)
SimOptDecisions.get_action(policy::StaticPolicy, state::State, t::TimeStep, scenario::Scenario) = ...
SimOptDecisions.run_timestep(state::State, action, t::TimeStep, config::Config, scenario::Scenario, rng) = ...
SimOptDecisions.compute_outcome(step_records::Vector{StepRecord}, config::Config, scenario::Scenario) = ...
```

**Usage:**

```julia
using ICOW
outcome = simulate(config, scenario, policy)  # SimOptDecisions.simulate dispatches on ICOW types
```
