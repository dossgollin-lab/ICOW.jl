# Simulation Modes

The iCOW model supports two distinct simulation modes for evaluating flood risk and mitigation strategies.

## Overview

### Stochastic Mode

Simulates specific realizations of storm surge events.

- **Input:** Pre-generated matrix of surge heights `[n_scenarios, n_years]`
- **Output:** Realized costs and damages for each scenario
- **Use cases:**
  - Characterizing variability across surge realizations
  - Distributional analysis (percentiles, tail risk)
  - Adaptive policies that respond to observed events
  - Validation and robustness testing

### Expected Annual Damage (EAD) Mode

Integrates over surge distributions analytically.

- **Input:** Vector of probability distributions (one per year)
- **Output:** Expected costs and expected damages
- **Use cases:**
  - Fast policy exploration and optimization
  - Static policies (all decisions at $t=0$)
  - Initial Pareto front generation
  - Efficient exploration when stochasticity is well-characterized

### When to Use Each Mode

| Criterion | Stochastic | EAD |
|-----------|------------|-----|
| Speed | Slower (many scenarios) | Faster (single integration) |
| Adaptive policies | Required | Not applicable |
| Tail risk analysis | Yes | Limited |
| Initial optimization | No | Yes |
| Validation | Yes | No |

## Powell Framework Connection

The simulation follows the Powell framework for sequential decision-making:

### State ($S_t$)

Current protection levels and accumulated metrics.
Represented by `StochasticState` or `EADState`.

- `current_levers`: Current protection configuration
- `accumulated_cost`: Total investment so far
- `accumulated_damage` / `accumulated_ead`: Cumulative damage metric
- `current_year`: Simulation progress

### Decision ($x_t$)

Lever settings determined by the policy.
The policy function returns a `Levers` struct: $X^\pi(S_t) \rightarrow$ `Levers`

### Exogenous Information ($W_{t+1}$)

Storm surge forcing.
Represented by `StochasticForcing` or `DistributionalForcing`.

- **Stochastic:** Realized surge value from pre-generated matrix
- **Distributional:** Probability distribution for integration

### Transition Function ($S^M$)

State update incorporating:

- Investment costs from lever changes
- Damage from surge events (or expected damage)
- Irreversibility enforcement via `max(current_levers, new_levers)`

### Contribution ($C$)

Investment costs plus damages (discounted).
Computed per timestep and accumulated in state.

## Convergence

For static policies, the mean of stochastic simulations should converge to EAD mode results as $n_{scenarios} \rightarrow \infty$ (Law of Large Numbers).
