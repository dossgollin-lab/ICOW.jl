# Technical Specification: `iCOW.jl`

## Executive Summary

The **Island City on a Wedge (iCOW)** model is an intermediate-complexity framework for simulating coastal storm surge risk and optimizing mitigation strategies. Originally developed by Ceres et al. (2019), it bridges the gap between simple economic models (like Van Dantzig) and computationally expensive hydrodynamic models.  
The model simulates a city located on a rising coastal "wedge". It evaluates the trade-offs between two conflicting objectives:

1. **Minimizing Investment:** Costs of withdrawal, flood-proofing (resistance), and building dikes.  
2. **Minimizing Damages:** Economic loss from storm surges over time.

**Project Goal:** Implement a performant, modular Julia version of iCOW that supports:

* **Static Optimization:** Replicating the paper's results (Pareto front analysis).  
* **Dynamic Policy Search:** Optimizing adaptive rules (e.g., "raise dike if surge > $x$") under deep uncertainty.
* **Forward Mode Analysis:** Generating rich, high-dimensional datasets (Time × Scenarios × Strategies) for visualization via YAXArrays.jl.

## Design Principles

1. **Functional Core, Mutable Shell:**  
   * Physics calculations (cost, volume, damage) must be **pure functions**. They take parameters and return values with no side effects.  
   * State (current year, accumulated cost) is managed only within the Simulation Engine loop.  
2. **Allocation-Free Inner Loops:**  
   * The optimization loop will run millions of evaluations. Avoid creating temporary arrays or structs inside the simulate function.  
   * Use StaticArrays.jl for small coordinate vectors if necessary, though scalars are likely sufficient.  
3. **Strict Separation of "Brain" and "Body":**  
   * **Body (Physics):** Determines *how much* a 5m dike costs and *how much* damage a 3m surge causes.  
   * **Brain (Policy):** Determines *when* to build that dike.  
   * The simulation engine should not care if the decision came from a static array or a neural network.  
4. **Data as an Artifact:**  
   * Surge scenarios (States of the World) are pre-generated and passed as inputs. The simulation functions should be deterministic given a specific surge input.

## Key Equations (To Be Verified)

**IMPORTANT:** The following equations must be transcribed directly from Ceres et al. (2019) and verified by a human before implementation. These should be documented as LaTeX in function docstrings.

### Dike Volume (Equation 6)

**Status:** Placeholder. Implement based on Ceres et al. (2019) section 2.4, Figure 2.

**Expected Form:** Likely a U-shaped dike on a wedge, with volume depending on dike height $D$, dike base elevation $B$, and slope parameters.

```latex
% TODO: Transcribe exact formula from paper
% V_{dike}(D, B) = ...
```

### Investment Cost (Withdrawal, Resistance, Dike)

**Withdrawal Cost (Eq 1):**

```latex
% TODO: Transcribe exact formula
% C_W(W) = ...
```

**Resistance Cost (Eq 4 and Eq 5):**

```latex
% TODO: Define cost function for resistance height R and fraction P
% C_R(R, P) = ...
```

**Dike Cost (Eq 7):**

```latex
% TODO: Volume × cost per m³ + startup costs
% C_D(D, B) = V_{dike}(D, B) * c_{dpv} + C_{startup}
```

### Damage Calculation

**Dike Failure Probability (Eq 8):**

```latex
% TODO: Linear increase from threshold t_df to probability 1.0
% P_f(water_level, t_df) = ...
```

**Damage by Zone (Figure 3):**

```latex
% TODO: Define damage function for each zone (0, 1, 2, 3, 4)
% D(water_level) = ...
```

### Discounting Formula

Present Value Factor at year $t$:

$$PV_t = (1 + r)^{-(t-1)}$$

where $r$ is the discount rate (stored in `city.discount_rate`).

## Phase 1: Core Physics & Types (Stateless)

**Goal:** Implement the "physics" of the wedge city described in Ceres et al. (2019) section 2.4.

### Data Structures (src/types.jl)

* **`CityParameters`**: An immutable struct holding the exogenous factors ($X$).  
  * Use `Base.@kwdef` for easy initialization.  
  * **Fields:** `total_value` ($v_i$), `slope`, `dike_cost_per_m3` ($c_{dpv}$), `discount_rate`, `resistance_cost_factors` ($f_{lin}, f_{exp}$), `dike_startup_height`.  
  * *Default Values:* Must match Table C.3 in the paper.  
* **`Levers`**: An immutable struct representing the physical state of defenses ($L$).  
  * **Fields:**  
    * `withdraw_h` ($W$): Height below which city is removed.  
    * `resist_h` ($R$): Height of flood-proofing.  
    * `resist_p` ($P$): Percentage of resistance (0.0 \- 1.0).  
    * `dike_h` ($D$): Height of dike relative to base.  
    * `dike_base_h` ($B$): Elevation of dike base.

### Physics Functions (src/physics.jl)

**Implementation Note:** All physics functions must have complete LaTeX docstrings with the exact equations from the paper *before* implementation. See "Key Equations" section above.

* **`calculate_dike_volume(city, D, B)`**:  
  * **Logic:** Implement Equation 6\. This calculates the volume of a U-shaped dike on a wedge.  
  * *Note:* This is geometrically complex; implement as a standalone, unit-tested function.  
* **`calculate_investment_cost(city, levers)`**:  
  * **Logic:** Sum of:  
    1. **Withdrawal:** Based on area relocated (Eq 1).  
    2. **Resistance:** Cost function changes if constrained by dike (Eq 4 vs Eq 5).  
    3. **Dike:** Volume $\times$ Cost per $m^3$ + Startup Costs (Eq 7).  
* **`calculate_event_damage(city, levers, surge_height)`**:  
  * **Logic:**  
    1. Determine Water Level: surge - seawall.  
    2. Check Dike Failure: Probability increases linearly from threshold ($t_{df}$) to 1.0 (Eq 8).  
    3. Calculate Damage by Zone (0, 1, 2, 3, 4) per Fig 3.  
    4. Apply `damage_fraction` ($f_{damage}$) and value density.

## Phase 2: Simulation Engine (Stateful)

**Goal:** A time-stepping engine that handles state, discounting, and irreversibility.

### Simulation State (src/simulation.jl)

```julia
mutable struct SimulationState  
    current_levers::Levers  
    accumulated_cost::Float64  
    accumulated_damage::Float64  
    surge_history::Vector{Float64} # For calculation of signposts  
    year::Int  
end
```

### The Engine Logic

* **`simulate(city, policy, surge_sequence; mode=:scalar)`**:  
  * **Input:** `surge_sequence` is a `Vector{Float64}` (one timeline).  
  * **Loop:** Iterate $t = 1$ to $T$ (e.g., 50 years).  
    1. **Get Target:** `target_levers = decide(policy, state)`.  
    2. **Enforce Irreversibility:** `effective_levers = max.(target_levers, state.current_levers)`. (Cannot unbuild a dike).  
    3. **Calc Marginal Cost:**  
       * `cost_new = calculate_investment_cost(city, effective_levers)`  
       * `cost_old = calculate_investment_cost(city, state.current_levers)`  
       * `investment = max(0.0, cost_new - cost_old)`  
    4. **Calc Damage:** `dmg = calculate_event_damage(city, effective_levers, surge_sequence[t])`.  
    5. **Apply Discounting:** `discounted_investment = investment * (1 + city.discount_rate)^(-(t-1))` and `discounted_dmg = dmg * (1 + city.discount_rate)^(-(t-1))`.  
    6. **Accumulate:** `state.accumulated_cost += discounted_investment` and `state.accumulated_damage += discounted_dmg`.  
    7. **Update State:** `state.current_levers = effective_levers`, `state.surge_history[t] = surge_sequence[t]`, `state.year = t`.  
    8. **Trace (Optional):** If `mode == :trace`, push `(t, investment, dmg, effective_levers...)` to a pre-allocated history buffer.

## Phase 3: Policies

**Goal:** Define the logic for *when* to implement defenses.

### Abstract Interface (src/policies.jl)

* `abstract type AbstractPolicy`  
* `decide(policy::AbstractPolicy, state::SimulationState) -> Levers`

### Implementations

1. **`StaticPolicy`**:  
   * **Fields:** `target::Levers` (the target defense strategy set at time zero).  
   * **Logic:** If `state.year == 1`, return `target`. Else, return `state.current_levers`.  
   * *Purpose:* Matches the Ceres et al. paper methodology where strategies are set at time zero.  
2. **`ThresholdPolicy`** (Dynamic):  
   * **Fields:** `trigger_value` (Float), `increment` (Float).  
   * **Logic:** Calculate moving average of `state.surge_history`. If avg > trigger, return `current_dike` + increment.  
   * *Purpose:* Classroom assignments on adaptive planning.

## Phase 4: Optimization Wrapper

**Goal:** Interface with Metaheuristics.jl with proper handling of physical constraints.

### Physical Constraints

The iCOW model has several hard physical constraints that must be enforced:

1. **Dike Elevation:** `dike_base_h` (B) + `dike_h` (D) ≤ `city_max_height` (dike cannot exceed maximum city elevation).
2. **Withdrawal Level:** `withdraw_h` (W) ≤ `dike_base_h` (B) (city cannot be withdrawn below dike base).
3. **Resistance Percentage:** 0.0 ≤ `resist_p` (P) ≤ 1.0 (resistance fraction must be between 0% and 100%).
4. **All Heights Non-Negative:** B, D, W, R ≥ 0.

**Implementation Strategy:** Metaheuristics.jl primarily handles box constraints (bounds). For physical constraints:

* **Penalty Method (Recommended):** In the objective function, check if constraints are violated. If so, return `[Inf, Inf]` (infinite cost and damage) or a large penalty term. This guides the optimizer away from infeasible regions while allowing it to explore safely.
* **Alternative:** Encode constraints directly in `calculate_investment_cost` by returning `Inf` when any constraint is violated. This ensures the optimizer never evaluates invalid designs.

**Example Pseudo-Code:**

```julia
function is_feasible(levers::Levers, city::CityParameters)
    return (levers.dike_base_h + levers.dike_h ≤ city.city_max_height) &&
           (levers.withdraw_h ≤ levers.dike_base_h) &&
           (0.0 ≤ levers.resist_p ≤ 1.0) &&
           all([levers.dike_base_h, levers.dike_h, levers.withdraw_h, levers.resist_h] .≥ 0)
end

function simulate(city, policy, surge_sequence; mode=:scalar)
    # ... inside the loop ...
    if !is_feasible(effective_levers, city)
        return [Inf, Inf]  # Reject infeasible design
    end
    # ... continue with normal simulation ...
end
```

### Wrapper Functions (src/optimization.jl)

* **`optimize_portfolio(city, surge_matrix, policy_type; n_gen=100)`**:  
  1. **Define Bounds:** Map the 5 levers to optimization bounds:  
     * `withdraw_h`: $[0, B_{max}]$  
     * `resist_h`: $[0, D_{max}]$  
     * `resist_p`: $[0, 1]$  
     * `dike_h`: $[0, 15m]$ (or problem-specific max).  
     * `dike_base_h`: $[0, C_{max} - D_{max}]$ (ensuring $B + D \leq C_{max}$).  
  2. **Define Objective f(x):**  
     * Decode `x` (vector of length 5) into a `Levers` struct.  
     * **Check Feasibility:** If constraints are violated (see Physical Constraints section), return `[Inf, Inf]`.  
     * Run `simulate` for all rows in `surge_matrix` using `mode=:scalar`.  
     * Aggregate results: `mean_cost = mean([result.accumulated_cost for each scenario])`, similarly for `mean_damage`.  
     * Return $[\text{mean_cost}, \text{mean_damage}]$.  
  3. **Solve:** Call `Metaheuristics.optimize(f, bounds, NSGA2(); options...)`.  
  4. **Return:** A custom struct containing the Pareto front and raw optimization result.

## Phase 5: Analysis & Data (YAXArrays)

**Goal:** "Forward Mode" output for visualization.

### Data Aggregation (src/analysis.jl)

* **`run_forward_mode(city, policy, surge_matrix)`**:  
  * **Input:** A `surge_matrix` of shape $(N_{scenarios} \times T_{years})$.  
  * **Logic:**  
    1. Initialize a storage container.  
    2. Iterate over every scenario row in `surge_matrix`.  
    3. Run `simulate(..., mode=:trace)` to get the full timeline of that scenario.  
    4. Collect results into a standard format.  
  * **Output:** A YAXArray (or Dataset) with dimensions:  
    * Time: $1 \dots 50$  
    * Scenario: $1 \dots N$  
    * Variable: `[:investment_cost, :damage, :dike_height, :surge_level]`  
  * **Why:** This output structure allows for immediate plotting of "spaghetti plots" (all futures) or calculating quantiles (e.g., 90th percentile damage) using `YAXArrays.jl` built-ins.

## Testing Strategy

**Goal:** Minimalist but effective tests.

1. **`test/physics_tests.jl` (Unit Tests):**  
   * **Volume:** Test `calculate_dike_volume` against a known hand-calculation (e.g., a simple square case).  
   * **Monotonicity:** Verify that `calculate_investment_cost` *always* increases as dike height increases.  
   * **Safety:** Verify `calculate_event_damage` is 0.0 when surge < seawall.  
2. **`test/van_dantzig_test.jl` (Regression/Integration):**  
   * **Setup:** Create a scenario with 50 identical years.  
   * **Action:** Optimize a `StaticPolicy` where ONLY `dike_h` is allowed to change (fix others to 0).  
   * **Verify:** Plotting Cost + Damage vs. Height should produce the U-shaped curve (convex) shown in Appendix A (Fig A.6).  
3. **`test/forward_mode_test.jl` (Functional):**  
   * **Action:** Run `run_forward_mode` on a small matrix ($2 \times 5$).  
   * **Verify:** Output is a valid `YAXArray` and `diff(dike_height)` is never negative (infrastructure never shrinks).
