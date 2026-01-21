# ICOW.jl SimOptDecisions Integration

Completed refactor for SimOptDecisions 5-callback interface.

## Architecture

### Type Hierarchy

```
CityParameters <: AbstractConfig     # City parameters (immutable)
State <: AbstractState               # current_levers + current_sea_level
EADScenario <: AbstractScenario      # EAD mode with TimeSeriesParameter sea_level
StochasticScenario <: AbstractScenario  # Stochastic mode with TimeSeriesParameter sea_level
StaticPolicy <: AbstractPolicy       # Fixed lever settings
Levers <: AbstractAction             # W, R, P, D, B
```

### 5-Callback Implementation

| Callback | Location | Purpose |
|----------|----------|---------|
| `initialize` | simulation.jl | Create initial State with zero levers |
| `time_axis` | simulation.jl | Return `1:n_years(scenario)` |
| `get_action` | policies.jl | Get levers from policy callable |
| `run_timestep` | simulation.jl | Execute one year, return `(new_state, step_record)` |
| `compute_outcome` | simulation.jl | NPV aggregation of step records |

### Sea Level Rise Support

- `Scenario.sea_level::TimeSeriesParameter{T,Int}` - indexed by year
- `State.current_sea_level::T` - updated each timestep
- Default: constant zero sea level
- SLR: pass custom TimeSeriesParameter to scenario constructor

## Usage

```julia
using ICOW
import SimOptDecisions

# Create forcing
surges = rand(100, 50)  # 100 scenarios, 50 years
forcing = StochasticForcing(surges)

# Create scenario with SLR trajectory
sea_level = SimOptDecisions.TimeSeriesParameter(
    collect(1:50),          # years
    0.003 .* (1:50)         # 3mm/year SLR
)
scenario = StochasticScenario(forcing, 1; discount_rate=0.03, sea_level=sea_level)

# Run simulation
city = CityParameters()
policy = StaticPolicy(Levers(0.0, 0.0, 0.0, 5.0, 0.0))
result = SimOptDecisions.simulate(city, scenario, policy, Random.default_rng())

# result.investment, result.damage are discounted NPV totals
```

## Optimization

```julia
forcings = [StochasticForcing(rand(100, 50)) for _ in 1:3]
result = optimize(city, forcings, 0.03; max_iterations=100)

for (policy, objectives) in pareto_policies(result, StaticPolicy{Float64})
    println(policy.levers, " => ", objectives)
end
```
