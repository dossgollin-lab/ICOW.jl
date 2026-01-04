# Theoretical Framework

This document establishes the analytical framework for iCOW.
We build on the physical model of Ceres et al. (2019) but extend it to sequential decision-making under deep uncertainty.

## The System Model

The iCOW model is a black-box function that maps a **(policy, SOW)** pair to **outcomes**:

$$f(\pi, \mathbf{s}) \to \text{outcomes}$$

where $\pi$ is a policy (decision rule), $\mathbf{s}$ is a state of the world, and outcomes include costs, damages, and other quantities of interest.

### Physical Model

The underlying physics come from Ceres et al. (2019).
iCOW models a coastal city as a triangular wedge rising from sea level to peak elevation $H_{\text{city}}$.
Property value is distributed linearly with elevation.
Storm surge is the hazard: when water reaches elevation $h$, everything below $h$ floods.

### Decision Levers

The city has five protective levers—**withdrawal** ($W$), **resistance** ($R$, $P$), and **dike** ($B$, $D$)—that partition the city into zones with different damage characteristics:

| Lever | What it does                                                        | Support                        |
| ----- | ------------------------------------------------------------------- | ------------------------------ |
| $W$   | Relocate all value below elevation $W$                              | $[0, H_{\text{city}}]$         |
| $R$   | Floodproof buildings from $W$ to $W+R$; reduces damage by factor $P$| $[0, \infty)$                  |
| $P$   | Fraction of damage prevented by floodproofing                       | $[0, 1)$                       |
| $B$   | Place dike base at elevation $W+B$                                  | $[0, H_{\text{city}} - W]$     |
| $D$   | Build dike to height $D$ above its base                             | $[0, H_{\text{city}} - W - B]$ |

The damage and cost equations are in `equations.md`.

### States of the World

A **state of the world (SOW)** $\mathbf{s}$ specifies all exogenous factors needed to evaluate a policy: sea-level rise trajectory, surge distribution parameters, and (in stochastic mode) realized surge events.

SOWs may be sampled from different **probabilistic scenarios** (e.g., combinations of emissions pathways and ice sheet models).
Each scenario defines a distribution over SOWs.
But we typically have multiple scenarios that disagree—this is **deep uncertainty**.

## Aggregating Over SOWs

To evaluate how good a *policy* is, we must aggregate outcomes across SOWs.
A single policy-SOW evaluation tells us "policy $\pi$ yields outcome $u$ under SOW $\mathbf{s}_j$."
To get **policy-level performance metrics**, we aggregate:

$$\mathbb{E}[f(\pi, \mathbf{s})] \approx \sum_{j=1}^{N} w_j \, f(\pi, \mathbf{s}_j)$$

where $w_j$ are weights satisfying $\sum_{j=1}^{N} w_j = 1$.

This is the key step that transforms SOW-level outcomes into policy-level metrics.

### SOW Weights

The weights $w_j$ encode beliefs about the relative likelihood of different SOWs.
Following Doss-Gollin & Keller (2023), weights can be derived from a subjective probability distribution $p_{\text{belief}}(\psi)$ over a summary statistic (e.g., sea level in 2100).
The weights are computed by partitioning the summary statistic space and integrating $p_{\text{belief}}$ over each partition.

Currently we assume **uniform weights** over an intelligently sampled ensemble, but the framework supports arbitrary weighting schemes.
This allows:

- Sensitivity analysis: how do conclusions change under different $p_{\text{belief}}$?
- Explicit assumptions: makes beliefs about SOW likelihood transparent
- Flexibility: can incorporate expert judgment or new information

## Performance Metrics

For each policy, the aggregation step produces **performance metrics**:

- Expected NPV of total costs (investment + damages)
- Expected annual damage
- Tail risk measures (e.g., 95th percentile damage)
- Other objectives as needed

We track multiple metrics but typically **optimize only a subset**.
Additional metrics can inform robustness analysis or provide context without driving the optimization.

Robustness (in the DMDU sense) is not built into the core framework, but can be incorporated through how metrics are defined—e.g., worst-case performance, regret, or satisficing thresholds.

## Policies

A **policy** $\pi$ is a rule that maps observable state to lever settings.
We focus on **parameterized policies**: families of decision rules indexed by parameters $\theta$.

Examples:

- **Static policy**: Choose $(W, R, P, D, B)$ at $t=0$, never change. Parameters are the initial lever settings.
- **Threshold policy**: "If sea-level rise exceeds threshold $\tau$ by year $t^*$, raise the dike by $\Delta D$." Parameters are $(\tau, t^*, \Delta D)$.
- **Trigger policy**: "After any flood exceeding damage $d^*$, increase resistance by $\Delta R$." Parameters are $(d^*, \Delta R)$.

### Sequential Decision-Making

Ceres et al. (2019) treated the problem as static optimization.
We extend this to **sequential decision-making** over a multi-decade planning horizon.

The state at time $t$ includes:

- Current lever settings (what's already built)
- Accumulated costs and damages
- Observable information (e.g., realized sea-level rise)

The key constraint is **irreversibility**: protection can be increased but not removed.
This means lever settings at $t+1$ must satisfy $\text{levers}_{t+1} \geq \text{levers}_t$ element-wise.

## Simulation Modes

Two approaches to computing $f(\pi, \mathbf{s})$:

**EAD mode** integrates damage analytically over the surge distribution:

$$\text{EAD}(t) = \int_0^\infty D(h, \text{levers}) \cdot p(h \mid \text{SLR}_t) \, dh$$

This is fast and sufficient for **static policies** where lever settings don't depend on realized events.

**Stochastic mode** draws surge realizations from each SOW and computes realized damage.
Required for **adaptive policies** that condition decisions on observed outcomes (e.g., "raise the dike after a major flood").

For static policies, stochastic mode converges to EAD mode as $n_{\text{samples}} \to \infty$.

## Optimization

The optimization problem is to find policy parameters $\theta$ that perform well according to the metrics we choose to optimize.
We search over $\theta$ to find Pareto-approximate sets trading off competing objectives (e.g., investment cost vs. expected damage).

## References

- Ceres et al. (2019). *Environ. Model. Softw.* — physical model (geometry, damage, costs)
- Doss-Gollin & Keller (2023). *Earth's Future.* — SOW aggregation framework
- Powell (2022). *Reinforcement Learning and Stochastic Optimization.* — sequential decision framework

*Damage and cost equations are in `equations.md`.*
