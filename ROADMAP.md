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

**Licensing:** This implementation must be compatible with GPLv3 open-source licensing, following the spirit of the original model release.

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

5. **Correctness Over Performance:**
   * Code clarity and correctness are primary goals.
   * Performance optimization is secondary and will be addressed via profiling if needed.

## Implementation Roadmap

### Phase 0: Parameters & Validation

**Goal:** Establish the foundational parameter types and constraint validation before any physics implementation.

#### File: `src/parameters.jl`

**`CityParameters`**: Immutable struct holding all exogenous factors ($X$) from Table C.3 (Ceres et al. 2019, p. 33).

```julia
Base.@kwdef struct CityParameters
    # City geometry
    total_value::Float64 = 1.5e12      # vi: Initial city value ($)
    building_height::Float64 = 30.0     # B: Building height (m)
    city_max_height::Float64 = 17.0     # Hcity: Height of city (m)
    city_depth::Float64 = 2000.0        # Depth from seawall to highest point (m)
    city_length::Float64 = 43000.0      # Length of seawall coast (m)
    seawall_height::Float64 = 1.75      # Height of seawall (m)
    city_slope::Float64 = 17.0/2000.0   # S: Slope of the wedge

    # Dike parameters
    dike_startup_height::Float64 = 3.0  # Equivalent height for startup costs (m)
    dike_top_width::Float64 = 4.0       # Width of dike top (m)
    dike_side_slope::Float64 = 0.5      # s: Slope of dike sides (m/m)
    dike_cost_per_m3::Float64 = 10.0    # cdpv: Cost per cubic meter ($)
    dike_value_ratio::Float64 = 1.1     # Value increase in dike-protected areas

    # Withdrawal parameters
    withdrawal_factor::Float64 = 1.0    # fw: Cost adjustment factor
    withdrawal_fraction::Float64 = 0.01 # fl: Fraction that leaves vs relocates

    # Resistance parameters
    resistance_linear_factor::Float64 = 0.35    # flin: Linear cost factor
    resistance_exp_factor::Float64 = 0.9        # fexp: Exponential cost factor
    resistance_threshold::Float64 = 0.6         # texp: Threshold for exponential costs
    basement_depth::Float64 = 3.0               # Representative basement depth (m)

    # Damage parameters
    damage_fraction::Float64 = 0.39             # fdamage: Fraction of inundated buildings damaged
    protected_damage_factor::Float64 = 1.3      # Increased damage when dike fails
    dike_failure_threshold::Float64 = 0.95      # tdf: Threshold for failure probability
    threshold_damage_level::Float64 = 1/375     # Damage threshold as fraction of city value
    wave_runup_factor::Float64 = 1.1            # Surge increase factor when overtopping

    # Economic parameters
    discount_rate::Float64 = 0.04       # Annual discount rate

    # Simulation parameters
    n_years::Int = 50                   # Simulation time horizon
end
```

**Parameter Validation:**

```julia
"""
Validate CityParameters for physical consistency.
Throws ArgumentError if invalid.
"""
function validate_parameters(city::CityParameters)
    @assert city.total_value > 0 "City value must be positive"
    @assert city.city_max_height > city.seawall_height "City must be higher than seawall"
    @assert 0 < city.discount_rate < 1 "Discount rate must be in (0, 1)"
    @assert city.city_slope ≈ city.city_max_height / city.city_depth "Inconsistent slope"
    @assert 0 ≤ city.resistance_threshold ≤ 1 "Resistance threshold must be in [0, 1]"
    @assert city.n_years > 0 "Simulation years must be positive"
    return true
end
```

#### File: `src/types.jl`

**`Levers`**: Immutable struct representing the physical state of defenses ($L$).

```julia
"""
    Levers

Represents the five decision levers for coastal defense strategies.

# Fields
- `withdraw_h::Float64`: W - Height below which city is relocated (m)
- `resist_h::Float64`: R - Height of flood-proofing (m)
- `resist_p::Float64`: P - Percentage of resistance (0.0 - 1.0)
- `dike_h::Float64`: D - Height of dike above base (m)
- `dike_base_h::Float64`: B - Elevation of dike base above seawall (m)

# Constraints
All levers are validated at construction time. Invalid configurations throw ArgumentError.
"""
struct Levers
    withdraw_h::Float64
    resist_h::Float64
    resist_p::Float64
    dike_h::Float64
    dike_base_h::Float64

    function Levers(W::Real, R::Real, P::Real, D::Real, B::Real;
                    city_max_height::Real=17.0,
                    validate::Bool=true)
        # Convert to Float64
        W, R, P, D, B = Float64.((W, R, P, D, B))

        # Validate if requested
        if validate
            # Constraint 1: Dike cannot exceed city height
            @assert B + D ≤ city_max_height "Dike top (B+D=$(B+D)) exceeds city max height ($city_max_height)"

            # Constraint 2: Withdrawal must be below dike base
            @assert W ≤ B "Withdrawal height ($W) cannot exceed dike base ($B)"

            # Constraint 3: Resistance percentage bounds
            @assert 0.0 ≤ P ≤ 1.0 "Resistance percentage ($P) must be in [0, 1]"

            # Constraint 4: All heights non-negative
            @assert all(≥(0), [W, R, D, B]) "All heights must be non-negative: W=$W, R=$R, D=$D, B=$B"
        end

        new(W, R, P, D, B)
    end
end

# Convenience constructor from vector (for optimization)
Levers(x::AbstractVector; kwargs...) = Levers(x[1], x[2], x[3], x[4], x[5]; kwargs...)

# Comparison for irreversibility checks
Base.max(l1::Levers, l2::Levers) = Levers(
    max(l1.withdraw_h, l2.withdraw_h),
    max(l1.resist_h, l2.resist_h),
    max(l1.resist_p, l2.resist_p),
    max(l1.dike_h, l2.dike_h),
    max(l1.dike_base_h, l2.dike_base_h);
    validate=false  # Already validated
)
```

**Feasibility Check:**

```julia
"""
    is_feasible(levers::Levers, city::CityParameters) -> Bool

Check if a set of levers satisfies all physical constraints.
Returns false if any constraint is violated.
"""
function is_feasible(levers::Levers, city::CityParameters)::Bool
    # These should be caught by Levers constructor, but double-check
    (levers.dike_base_h + levers.dike_h ≤ city.city_max_height) &&
    (levers.withdraw_h ≤ levers.dike_base_h) &&
    (0.0 ≤ levers.resist_p ≤ 1.0) &&
    all(≥(0), [levers.withdraw_h, levers.resist_h, levers.dike_h, levers.dike_base_h])
end
```

#### File: `docs/parameters.md`

Create a markdown file documenting all parameters from Tables C.3 and C.4 of Ceres et al. (2019), with:
* Parameter name
* Symbol
* Default value
* Units
* Physical interpretation
* Source (equation number or table)

---

### Phase 1a: Geometry

**Goal:** Implement the geometrically complex dike volume calculation (Equation 6).

#### File: `src/geometry.jl`

**Critical Equation from Paper (p. 17, Eq. 6):**

The dike volume $V_d$ for a U-shaped dike on a wedge is:

$$
V_d = W_{city} h \left( w_d + \frac{h}{s^2} \right) + \frac{1}{6} \left[ -\frac{h^4 (h + \frac{1}{s})^2}{s^2} - \frac{2h^5(h + \frac{1}{s})}{S^4} - \frac{4h^6}{s^2 S^4} + \frac{4h^4(2h(h + \frac{1}{s}) - \frac{4h^2}{s^2} + \frac{h^2}{s^2})}{s^2 S^2} + \frac{2h^3(h + \frac{1}{s})}{S^2} \right]^{1/2} + w_d \frac{h^2}{S^2}
$$

where:
* $h = D + D_{startup}$ (total height including startup)
* $D$ = dike height
* $D_{startup}$ = equivalent startup height
* $W_{city}$ = city width
* $w_d$ = dike top width
* $s$ = dike side slope
* $S$ = city slope

**Implementation Strategy:**

```julia
"""
    calculate_dike_volume(city::CityParameters, D::Real, B::Real) -> Float64

Calculate the volume of a U-shaped dike on a wedge geometry.

Implements Equation 6 from Ceres et al. (2019), Section 2.4.3, page 17.

# Arguments
- `city`: City parameters containing geometric constants
- `D`: Dike height above base (m)
- `B`: Dike base elevation above seawall (m) [currently unused, kept for API consistency]

# Returns
- Volume in cubic meters (m³)

# Notes
This is geometrically complex due to the wedge shape requiring irregular tetrahedrons
for the "wing" sections on the sloped sides of the city.

# LaTeX Formula
The complete equation involves:
1. Main rectangular section volume
2. Trapezoidal wing sections on city sides
3. Geometric corrections for irregular tetrahedrons

See docs/equations.md for complete derivation.
"""
function calculate_dike_volume(city::CityParameters, D::Real, B::Real)::Float64
    # Total effective height (including startup cost as height)
    h = D + city.dike_startup_height

    if h ≤ 0
        return 0.0
    end

    # Extract parameters for readability
    W_city = city.city_length
    w_d = city.dike_top_width
    s = city.dike_side_slope
    S = city.city_slope

    # Main rectangular volume term
    main_volume = W_city * h * (w_d + h / s^2)

    # Complex wing correction term (irregular tetrahedrons)
    # This is the [...] term in Eq 6
    term1 = -h^4 * (h + 1/s)^2 / s^2
    term2 = -2 * h^5 * (h + 1/s) / S^4
    term3 = -4 * h^6 / (s^2 * S^4)
    term4 = 4 * h^4 * (2*h*(h + 1/s) - 4*h^2/s^2 + h^2/s^2) / (s^2 * S^2)
    term5 = 2 * h^3 * (h + 1/s) / S^2

    wing_correction = sqrt(term1 + term2 + term3 + term4 + term5) / 6

    # Additional top-width correction
    top_correction = w_d * h^2 / S^2

    V_d = main_volume + wing_correction + top_correction

    return V_d
end

"""
    calculate_main_dike_volume(h, W_city, w_d, s) -> Float64

Helper function for main (rectangular cross-section) dike volume.
Used for testing and validation.
"""
function calculate_main_dike_volume(h, W_city, w_d, s)
    return W_city * h * (w_d + h/s^2)
end

"""
    calculate_wing_volume_correction(h, s, S) -> Float64

Helper function for wing volume correction due to wedge geometry.
Used for testing and validation.
"""
function calculate_wing_volume_correction(h, s, S)
    term1 = -h^4 * (h + 1/s)^2 / s^2
    term2 = -2 * h^5 * (h + 1/s) / S^4
    term3 = -4 * h^6 / (s^2 * S^4)
    term4 = 4 * h^4 * (2*h*(h + 1/s) - 4*h^2/s^2 + h^2/s^2) / (s^2 * S^2)
    term5 = 2 * h^3 * (h + 1/s) / S^2

    return sqrt(term1 + term2 + term3 + term4 + term5) / 6
end
```

**Testing Requirements:**

```julia
# test/geometry_tests.jl

@testset "Dike Volume Calculation" begin
    city = CityParameters()

    # Test 1: Zero height gives zero volume
    @test calculate_dike_volume(city, 0.0, 0.0) == 0.0

    # Test 2: Monotonicity - volume increases with height
    volumes = [calculate_dike_volume(city, D, 0.0) for D in 0:0.5:15]
    @test all(diff(volumes) .≥ 0)

    # Test 3: Hand calculation for simple case
    # TODO: Calculate expected volume for h=1m on flat terrain (S→0 limit)

    # Test 4: Numerical stability
    @test !isnan(calculate_dike_volume(city, 10.0, 0.0))
    @test !isinf(calculate_dike_volume(city, 10.0, 0.0))

    # Test 5: Compare with numerical integration (optional, expensive)
    # TODO: Implement Monte Carlo volume estimation for validation
end
```

---

### Phase 1b: Core Physics

**Goal:** Implement cost and damage functions based on exact equations from the paper.

#### File: `docs/equations.md`

Before implementation, create this file with all equations transcribed from the paper in LaTeX format. **This must be completed and reviewed before coding Phase 1b.**

Required equations:

1. **Eq 1** (p. 14): Withdrawal cost
2. **Eq 3** (p. 15): Resistance cost fraction
3. **Eq 4** (p. 15): Resistance cost (unconstrained)
4. **Eq 5** (p. 16): Resistance cost (constrained by dike)
5. **Eq 6** (p. 17): Dike volume [DONE in Phase 1a]
6. **Eq 7** (p. 17): Dike cost
7. **Eq 8** (p. 17): Dike failure probability
8. **Eq 9** (p. 18): Damage by zone

#### File: `src/costs.jl`

**Withdrawal Cost (Equation 1, p. 14):**

$$
C_W(W) = \frac{v_i \times W \times f_w}{H_{city} - W}
$$

where:
* $v_i$ = initial city value
* $W$ = withdrawal height
* $f_w$ = withdrawal adjustment factor
* $H_{city}$ = maximum city height

```julia
"""
    calculate_withdrawal_cost(city::CityParameters, W::Real) -> Float64

Calculate the cost of withdrawing from elevations below W.

Implements Equation 1 from Ceres et al. (2019), Section 2.4.1, page 14.

Cost is based on:
- Area to be relocated (proportional to W)
- Value density of that area
- Remaining area available for relocation
- Adjustment factor for local conditions (fw)

# LaTeX Formula
``C_W(W) = \\frac{v_i \\times W \\times f_w}{H_{city} - W}``

Returns cost in dollars.
"""
function calculate_withdrawal_cost(city::CityParameters, W::Real)::Float64
    if W ≤ 0
        return 0.0
    end

    # Avoid division by zero
    if W ≥ city.city_max_height
        return Inf
    end

    C_W = (city.total_value * W * city.withdrawal_factor) / (city.city_max_height - W)

    return C_W
end
```

**City Value After Withdrawal (Equation 2, p. 14):**

$$
v_w = v_i \times \left(1 - \frac{f_l \times W}{H_{city}}\right)
$$

where $f_l$ is the fraction that leaves rather than relocates.

```julia
"""
    calculate_value_after_withdrawal(city::CityParameters, W::Real) -> Float64

Calculate remaining city value after withdrawal.

Implements Equation 2 from Ceres et al. (2019), Section 2.4.1, page 14.

Some fraction (fl) of displaced infrastructure leaves the city entirely,
reducing total city value.
"""
function calculate_value_after_withdrawal(city::CityParameters, W::Real)::Float64
    if W ≤ 0
        return city.total_value
    end

    v_w = city.total_value * (1 - city.withdrawal_fraction * W / city.city_max_height)

    return max(0.0, v_w)
end
```

**Resistance Cost Fraction (Equation 3, p. 15):**

$$
f_{cR}(P) = f_{lin} \times P + \frac{f_{exp} \times \max(0, P - t_{exp})}{1 - P}
$$

```julia
"""
    calculate_resistance_cost_fraction(city::CityParameters, P::Real) -> Float64

Calculate the per-unit-value cost fraction for resistance as a function of percentage P.

Implements Equation 3 from Ceres et al. (2019), Section 2.4.2, page 15.

Cost increases linearly at low P, then exponentially as P → 1
(complete invulnerability is infinitely expensive).
"""
function calculate_resistance_cost_fraction(city::CityParameters, P::Real)::Float64
    if P ≤ 0
        return 0.0
    end

    # Avoid division by zero
    if P ≥ 1.0
        return Inf
    end

    linear_term = city.resistance_linear_factor * P

    exponential_term = if P > city.resistance_threshold
        city.resistance_exp_factor * (P - city.resistance_threshold) / (1 - P)
    else
        0.0
    end

    return linear_term + exponential_term
end
```

**Resistance Cost - Unconstrained (Equation 4, p. 15):**

When resistance is NOT constrained by a dike (R < B or no dike):

$$
C_R = \frac{v_w \times f_{cR}(P) \times R \times (R/2 + b)}{h \times (H_{city} - W)}
$$

**Resistance Cost - Constrained (Equation 5, p. 16):**

When resistance IS constrained by dike base (R ≥ B):

$$
C_R = \frac{v_w \times f_{cR}(P) \times B \times (R - B/2 + b)}{h \times (H_{city} - W)}
$$

```julia
"""
    calculate_resistance_cost(city::CityParameters, levers::Levers) -> Float64

Calculate total cost of implementing resistance strategy.

Implements Equations 4 and 5 from Ceres et al. (2019), Section 2.4.2, pages 15-16.

The cost formula changes depending on whether resistance is constrained by dike base:
- Unconstrained (Eq 4): Resistance zone extends from W to W+R
- Constrained (Eq 5): Resistance zone limited to W to B (dike base)

No resistance is applied behind the dike (zone 3) regardless of R.
"""
function calculate_resistance_cost(city::CityParameters, levers::Levers)::Float64
    R = levers.resist_h
    P = levers.resist_p
    W = levers.withdraw_h
    B = levers.dike_base_h

    if R ≤ 0 || P ≤ 0
        return 0.0
    end

    # Get value after withdrawal and cost fraction
    v_w = calculate_value_after_withdrawal(city, W)
    f_cR = calculate_resistance_cost_fraction(city, P)
    h = city.building_height
    b = city.basement_depth

    # Check if resistance is constrained by dike
    if R > B && B > 0
        # Constrained case (Equation 5)
        # Resistance only applied up to dike base
        C_R = (v_w * f_cR * B * (R - B/2 + b)) / (h * (city.city_max_height - W))
    else
        # Unconstrained case (Equation 4)
        # Resistance applied to full height R
        C_R = (v_w * f_cR * R * (R/2 + b)) / (h * (city.city_max_height - W))
    end

    return C_R
end
```

**Dike Cost (Equation 7, p. 17):**

$$
C_D = V_d \times c_{dpv}
$$

where $V_d$ is from Equation 6 and $c_{dpv}$ is cost per cubic meter.

```julia
"""
    calculate_dike_cost(city::CityParameters, D::Real, B::Real) -> Float64

Calculate cost of constructing a dike of height D at base elevation B.

Implements Equation 7 from Ceres et al. (2019), Section 2.4.3, page 17.

Cost is proportional to dike volume, which includes:
- Material costs (volume × cost_per_m³)
- Startup costs (embedded as equivalent additional height in volume calculation)
"""
function calculate_dike_cost(city::CityParameters, D::Real, B::Real)::Float64
    if D ≤ 0
        return 0.0
    end

    V_d = calculate_dike_volume(city, D, B)
    C_D = V_d * city.dike_cost_per_m3

    return C_D
end
```

**Total Investment Cost:**

```julia
"""
    calculate_investment_cost(city::CityParameters, levers::Levers) -> Float64

Calculate total upfront investment cost for a protection strategy.

Sum of:
1. Withdrawal cost (Eq 1)
2. Resistance cost (Eq 4 or 5)
3. Dike cost (Eq 7)

Returns total cost in dollars.
"""
function calculate_investment_cost(city::CityParameters, levers::Levers)::Float64
    C_W = calculate_withdrawal_cost(city, levers.withdraw_h)
    C_R = calculate_resistance_cost(city, levers)
    C_D = calculate_dike_cost(city, levers.dike_h, levers.dike_base_h)

    return C_W + C_R + C_D
end
```

#### File: `src/damage.jl`

**Dike Failure Probability (Equation 8, p. 17):**

$$
P_f(h_{surge}) = \begin{cases}
P_{min} & \text{if } h_{surge} < t_{df} \times D \\
\frac{h_{surge} - t_{df} \times D}{D - t_{df} \times D} & \text{if } t_{df} \times D \leq h_{surge} < D \\
1.0 & \text{if } h_{surge} \geq D
\end{cases}
$$

where:
* $h_{surge}$ = surge height above dike base
* $D$ = dike height
* $t_{df}$ = failure threshold (default 0.95)
* $P_{min}$ = minimum failure probability (very small, e.g., 0.001)

```julia
"""
    calculate_dike_failure_probability(surge_height::Real, D::Real, t_df::Real=0.95) -> Float64

Calculate probability that a dike fails given surge height.

Implements Equation 8 from Ceres et al. (2019), Section 2.4.3, page 17.

Dikes have:
- Low constant failure probability below threshold (improper maintenance, etc.)
- Linearly increasing failure probability from threshold to design height
- Certain failure (P=1.0) when overtopped
"""
function calculate_dike_failure_probability(surge_height::Real, D::Real,
                                           t_df::Real=0.95, P_min::Real=0.001)::Float64
    if D ≤ 0
        return 0.0  # No dike = no dike failure
    end

    threshold = t_df * D

    if surge_height < threshold
        return P_min
    elseif surge_height < D
        # Linear interpolation from threshold to certain failure
        return (surge_height - threshold) / (D - threshold)
    else
        return 1.0  # Overtopped
    end
end
```

**Damage Calculation (Equation 9, p. 18):**

Damage to each zone $z$ is:

$$
D_z = V_{alue}(z) \times \frac{V_{olume\_flooded}(z)}{V_{olume\_total}(z)} \times f_{damage}
$$

This is modified by:
* Resistance percentage P in zone 1
* Dike failure in zone 3 (increased damage if failed)
* Basement flooding (discrete damage when water reaches building base)

```julia
"""
    calculate_event_damage(city::CityParameters, levers::Levers, surge_height::Real) -> Float64

Calculate total economic damage from a single storm surge event.

Implements damage calculation logic from Ceres et al. (2019), Section 2.4.4, page 18.

Damage is calculated zone-by-zone based on:
- Zone 0 (Withdrawn): No damage
- Zone 1 (Resistant): Reduced damage by factor (1 - P)
- Zone 2 (Unprotected below dike): Full damage
- Zone 3 (Dike protected): Minimal damage unless dike fails
- Zone 4 (City heights): Full damage if surge reaches

Returns damage in dollars.
"""
function calculate_event_damage(city::CityParameters, levers::Levers,
                                surge_height::Real)::Float64
    # Effective surge height accounting for seawall and wave runup
    if surge_height ≤ city.seawall_height
        return 0.0  # Seawall protects
    end

    water_level = if surge_height > city.seawall_height
        (surge_height - city.seawall_height) * city.wave_runup_factor
    else
        0.0
    end

    # Calculate value after withdrawal
    v_w = calculate_value_after_withdrawal(city, levers.withdraw_h)

    # This is a simplified placeholder
    # Full implementation requires zone-by-zone calculation (see Phase 1c)
    # For now, use basic damage proportional to inundated area

    W = levers.withdraw_h
    R = levers.resist_h
    P = levers.resist_p
    B = levers.dike_base_h
    D = levers.dike_h

    # Determine effective water level accounting for dike
    effective_water = if D > 0
        # Check dike failure
        surge_above_base = max(0.0, water_level - B)
        P_fail = calculate_dike_failure_probability(surge_above_base, D, city.dike_failure_threshold)

        if rand() < P_fail  # Stochastic failure
            water_level * city.protected_damage_factor  # Increased damage when dike fails
        else
            max(0.0, water_level - (B + D))  # Only water overtopping dike causes damage
        end
    else
        water_level
    end

    # Calculate fraction of city inundated
    inundated_height = min(effective_water, city.city_max_height - W)

    if inundated_height ≤ 0
        return 0.0
    end

    # Basic damage proportional to value and inundated fraction
    # This is simplified - full version in Phase 1c calculates by zone
    damage_fraction = city.damage_fraction
    fraction_inundated = inundated_height / (city.city_max_height - W)

    # Adjust for resistance in lower areas
    if effective_water ≤ R
        damage_fraction *= (1 - P)  # Resistance reduces damage
    end

    damage = v_w * fraction_inundated * damage_fraction

    return damage
end
```

**Note:** The damage calculation above is a **simplified placeholder**. The full zone-by-zone implementation comes in Phase 1c.

---

### Phase 1c: Zones & City Characterization

**Goal:** Implement the complete zone-based city model from Figure 3 of the paper.

#### File: `src/zones.jl`

**Zone Definitions (from Figure 3, p. 11):**

* **Zone 0** (Withdrawn): 0 ≤ elevation < W. No value, no damage.
* **Zone 1** (Resistant): W ≤ elevation < min(W+R, B). Resistant buildings, reduced damage.
* **Zone 2** (Unprotected): min(W+R, B) ≤ elevation < B. Exists only if R < B. Full damage.
* **Zone 3** (Dike Protected): B ≤ elevation < B+D. Protected unless dike fails.
* **Zone 4** (City Heights): B+D ≤ elevation ≤ H_city. Unprotected, full damage.

```julia
"""
Zone boundaries and characteristics for the wedge city.
Each zone has different damage vulnerability based on protection strategies.
"""
struct CityZone
    lower_elevation::Float64    # Lower bound (m above seawall)
    upper_elevation::Float64    # Upper bound (m above seawall)
    value_density::Float64      # Value per unit height ($/m)
    damage_modifier::Float64    # Damage multiplier (0 = immune, 1 = full damage)
    is_protected::Bool          # Protected by dike?
end

"""
    calculate_city_zones(city::CityParameters, levers::Levers) -> Vector{CityZone}

Partition the city into zones based on protection strategies.

Returns vector of CityZone structs ordered by increasing elevation.

Zone structure depends on lever settings:
- Always have zones 0 and 4 (boundaries)
- Zone 1 exists if R > 0
- Zone 2 exists if R < B (gap between resistance and dike)
- Zone 3 exists if D > 0
"""
function calculate_city_zones(city::CityParameters, levers::Levers)::Vector{CityZone}
    W = levers.withdraw_h
    R = levers.resist_h
    P = levers.resist_p
    B = levers.dike_base_h
    D = levers.dike_h
    H = city.city_max_height

    zones = CityZone[]

    # Calculate total remaining value and density after withdrawal
    v_w = calculate_value_after_withdrawal(city, W)
    remaining_height = H - W
    value_density = remaining_height > 0 ? v_w / remaining_height : 0.0

    # Zone 0: Withdrawn area (0 to W)
    if W > 0
        push!(zones, CityZone(0.0, W, 0.0, 0.0, false))
    end

    # Zone 1: Resistant area (W to min(W+R, B))
    resistance_top = if B > 0
        min(W + R, B)  # Capped at dike base
    else
        W + R  # No dike constraint
    end

    if R > 0 && resistance_top > W
        damage_mod = 1.0 - P  # Resistance reduces damage by factor P
        push!(zones, CityZone(W, resistance_top, value_density, damage_mod, false))
    end

    # Zone 2: Unprotected gap (min(W+R, B) to B)
    # Only exists if resistance doesn't reach dike base
    if B > 0 && resistance_top < B
        push!(zones, CityZone(resistance_top, B, value_density, 1.0, false))
    end

    # Zone 3: Dike protected (B to B+D)
    if D > 0
        # Low damage unless dike fails
        # Damage modifier applied dynamically based on failure probability
        push!(zones, CityZone(B, B + D, value_density, 0.0, true))
    end

    # Zone 4: City heights (B+D to H)
    # Unprotected upper city
    top_start = max(W, B + D)
    if top_start < H
        push!(zones, CityZone(top_start, H, value_density, 1.0, false))
    end

    return zones
end

"""
    calculate_zone_damage(zone::CityZone, water_level::Real, city::CityParameters) -> Float64

Calculate damage to a single zone given water level.

Damage is based on:
1. Volume of zone flooded (proportional to height)
2. Value density in zone
3. Damage modifier (resistance factor)
4. Basement flooding (discrete jump at building base)
"""
function calculate_zone_damage(zone::CityZone, water_level::Real,
                               city::CityParameters)::Float64
    # No damage if water doesn't reach zone
    if water_level ≤ zone.lower_elevation
        return 0.0
    end

    # Calculate flooded height within zone
    flooded_height = min(water_level, zone.upper_elevation) - zone.lower_elevation
    zone_height = zone.upper_elevation - zone.lower_elevation

    if zone_height ≤ 0 || flooded_height ≤ 0
        return 0.0
    end

    # Damage proportional to flooded fraction
    flooded_fraction = flooded_height / zone_height
    zone_value = zone.value_density * zone_height

    # Base damage from flooding
    damage = zone_value * flooded_fraction * city.damage_fraction * zone.damage_modifier

    # Add basement flooding damage (discrete jump when water reaches building)
    # This is a simplification - full version tracks basement depth per building
    if water_level ≥ zone.lower_elevation
        basement_fraction = city.basement_depth / city.building_height
        basement_damage = zone_value * basement_fraction * city.damage_fraction * zone.damage_modifier
        damage += basement_damage
    end

    return damage
end
```

**Full Damage Calculation with Zones:**

```julia
"""
    calculate_event_damage_full(city::CityParameters, levers::Levers,
                                surge_height::Real) -> Float64

Complete zone-by-zone damage calculation.

This replaces the simplified version from Phase 1b.
"""
function calculate_event_damage_full(city::CityParameters, levers::Levers,
                                     surge_height::Real)::Float64
    # Check if surge exceeds seawall
    if surge_height ≤ city.seawall_height
        return 0.0
    end

    # Calculate effective water level with wave runup
    water_level = (surge_height - city.seawall_height) * city.wave_runup_factor

    # Get city zones
    zones = calculate_city_zones(city, levers)

    total_damage = 0.0

    for zone in zones
        if zone.is_protected
            # Special handling for dike-protected zone (zone 3)
            surge_above_base = max(0.0, water_level - zone.lower_elevation)
            D = levers.dike_h

            P_fail = calculate_dike_failure_probability(surge_above_base, D,
                                                        city.dike_failure_threshold)

            # Stochastic dike failure
            if rand() < P_fail
                # Dike failed - increased damage
                effective_water = water_level * city.protected_damage_factor
                damage = calculate_zone_damage(zone, effective_water, city)
            else
                # Dike holds - only overtopping causes damage
                effective_water = max(0.0, water_level - (zone.lower_elevation + D))
                damage = calculate_zone_damage(zone, effective_water, city)
            end

            total_damage += damage
        else
            # Regular zone - direct damage
            damage = calculate_zone_damage(zone, water_level, city)
            total_damage += damage
        end
    end

    return total_damage
end
```

**Testing:**

```julia
# test/zones_tests.jl

@testset "Zone Calculations" begin
    city = CityParameters()

    # Test 1: No protection = single zone (zone 4)
    levers_none = Levers(0, 0, 0, 0, 0)
    zones = calculate_city_zones(city, levers_none)
    @test length(zones) == 1
    @test zones[1].upper_elevation == city.city_max_height

    # Test 2: Withdrawal creates zone 0
    levers_withdraw = Levers(5, 0, 0, 0, 0)
    zones = calculate_city_zones(city, levers_withdraw)
    @test any(z -> z.upper_elevation == 5.0 && z.value_density == 0.0, zones)

    # Test 3: Resistance creates zone 1
    levers_resist = Levers(0, 3, 0.5, 0, 0)
    zones = calculate_city_zones(city, levers_resist)
    @test any(z -> z.damage_modifier == 0.5, zones)

    # Test 4: Dike creates zone 3
    levers_dike = Levers(0, 0, 0, 5, 2)
    zones = calculate_city_zones(city, levers_dike)
    @test any(z -> z.is_protected, zones)

    # Test 5: All strategies together
    levers_all = Levers(2, 3, 0.6, 5, 4)
    zones = calculate_city_zones(city, levers_all)
    @test length(zones) ≥ 3  # At minimum: withdrawn, resistant, protected, heights
end

@testset "Damage Monotonicity" begin
    city = CityParameters()
    levers = Levers(0, 0, 0, 0, 0)

    # Damage should increase with surge height
    damages = [calculate_event_damage_full(city, levers, s) for s in 0:0.5:10]
    @test all(diff(damages) .≥ 0)

    # Damage should be zero below seawall
    @test calculate_event_damage_full(city, levers, city.seawall_height - 0.1) == 0.0
end
```

---

### Phase 2: Simulation Engine

**Goal:** Time-stepping simulation with state management, discounting, and irreversibility.

#### File: `src/simulation.jl`

```julia
"""
    SimulationState

Mutable state container for time-stepping simulation.

Tracks:
- Current protection levels (levers)
- Accumulated discounted costs and damages
- Surge history (for dynamic policies)
- Current year
"""
mutable struct SimulationState
    current_levers::Levers
    accumulated_cost::Float64
    accumulated_damage::Float64
    surge_history::Vector{Float64}
    year::Int

    function SimulationState(n_years::Int)
        initial_levers = Levers(0, 0, 0, 0, 0)
        new(initial_levers, 0.0, 0.0, zeros(n_years), 1)
    end
end

"""
    simulate(city::CityParameters, policy::AbstractPolicy,
             surge_sequence::AbstractVector{Float64};
             mode::Symbol=:scalar) -> Union{NamedTuple, DataFrame}

Run time-stepping simulation of coastal defense strategy.

# Arguments
- `city`: City parameters
- `policy`: Decision policy (static or dynamic)
- `surge_sequence`: Vector of annual maximum surge heights (m)
- `mode`: Output mode
  - `:scalar` - Return only final accumulated metrics (for optimization)
  - `:trace` - Return full time-series DataFrame (for analysis)

# Returns
- If `mode == :scalar`: `(cost=Float64, damage=Float64)`
- If `mode == :trace`: DataFrame with columns [year, investment, damage, W, R, P, D, B, surge]

# Algorithm
For each year t:
1. Get target levers from policy
2. Enforce irreversibility (can't unbuild)
3. Calculate marginal investment cost
4. Calculate damage from surge
5. Apply discounting
6. Accumulate totals
7. Update state
"""
function simulate(city::CityParameters,
                 policy::AbstractPolicy,
                 surge_sequence::AbstractVector{Float64};
                 mode::Symbol=:scalar)

    @assert mode ∈ [:scalar, :trace] "Mode must be :scalar or :trace"
    @assert length(surge_sequence) == city.n_years "Surge sequence length must match n_years"

    # Initialize state
    state = SimulationState(city.n_years)

    # Pre-allocate trace buffer if needed
    trace = if mode == :trace
        DataFrame(
            year = Int[],
            investment = Float64[],
            damage = Float64[],
            W = Float64[],
            R = Float64[],
            P = Float64[],
            D = Float64[],
            B = Float64[],
            surge = Float64[]
        )
    else
        nothing
    end

    # Time-stepping loop
    for t in 1:city.n_years
        # 1. Get target levers from policy
        target_levers = decide(policy, state)

        # 2. Enforce irreversibility (cannot reduce protection)
        effective_levers = max(target_levers, state.current_levers)

        # 3. Calculate marginal investment cost
        cost_new = calculate_investment_cost(city, effective_levers)
        cost_old = calculate_investment_cost(city, state.current_levers)
        investment = max(0.0, cost_new - cost_old)

        # 4. Calculate damage from this year's surge
        surge = surge_sequence[t]
        damage = calculate_event_damage_full(city, effective_levers, surge)

        # 5. Apply discounting (present value)
        discount_factor = (1 + city.discount_rate)^(-(t - 1))
        discounted_investment = investment * discount_factor
        discounted_damage = damage * discount_factor

        # 6. Accumulate
        state.accumulated_cost += discounted_investment
        state.accumulated_damage += discounted_damage

        # 7. Update state
        state.current_levers = effective_levers
        state.surge_history[t] = surge
        state.year = t

        # 8. Record trace if requested
        if mode == :trace
            push!(trace, (
                year = t,
                investment = investment,
                damage = damage,
                W = effective_levers.withdraw_h,
                R = effective_levers.resist_h,
                P = effective_levers.resist_p,
                D = effective_levers.dike_h,
                B = effective_levers.dike_base_h,
                surge = surge
            ))
        end
    end

    # Return results based on mode
    if mode == :scalar
        return (cost = state.accumulated_cost, damage = state.accumulated_damage)
    else
        return trace
    end
end

"""
    simulate_ensemble(city::CityParameters, policy::AbstractPolicy,
                     surge_matrix::AbstractMatrix{Float64};
                     mode::Symbol=:scalar) -> Vector{NamedTuple}

Run simulation across multiple surge scenarios (ensemble).

# Arguments
- `surge_matrix`: Matrix of size (n_scenarios × n_years)

Returns vector of results, one per scenario.
"""
function simulate_ensemble(city::CityParameters,
                          policy::AbstractPolicy,
                          surge_matrix::AbstractMatrix{Float64};
                          mode::Symbol=:scalar)

    n_scenarios = size(surge_matrix, 1)

    results = Vector{Any}(undef, n_scenarios)

    for i in 1:n_scenarios
        surge_sequence = surge_matrix[i, :]
        results[i] = simulate(city, policy, surge_sequence; mode=mode)
    end

    return results
end
```

---

### Phase 3: Policies

**Goal:** Both static and dynamic policy implementations.

#### File: `src/policies.jl`

```julia
"""
    AbstractPolicy

Abstract base type for coastal defense policies.

A policy determines the target lever settings at each time step
based on the current simulation state.
"""
abstract type AbstractPolicy end

"""
    decide(policy::AbstractPolicy, state::SimulationState) -> Levers

Determine target lever settings based on current state.

This is the core "brain" function that all policies must implement.
"""
function decide end  # Must be implemented by subtypes

# ============================================================================
# Static Policy
# ============================================================================

"""
    StaticPolicy

Static protection strategy set at time zero and maintained.

This matches the methodology in Ceres et al. (2019) where strategies
are determined via optimization and implemented immediately.

# Fields
- `target::Levers`: The protection levels to implement at t=1

# Example
```julia
policy = StaticPolicy(Levers(0, 0, 0, 5, 2))  # 5m dike at 2m elevation
```

"""
struct StaticPolicy <: AbstractPolicy
    target::Levers
end

"""
    decide(policy::StaticPolicy, state::SimulationState) -> Levers

Static policy always returns the target levers at t=1, then maintains them.
"""
function decide(policy::StaticPolicy, state::SimulationState)::Levers
    if state.year == 1
        return policy.target
    else
        # Maintain current levers (irreversibility handled by simulate())
        return state.current_levers
    end
end

# ============================================================================

# Threshold Policy (Dynamic)

# ============================================================================

"""
    ThresholdPolicy

Dynamic policy that raises dike height when surge threshold is exceeded.

Monitors recent surge history and increases dike when moving average
exceeds trigger level.

# Fields

- `window::Int`: Number of years for moving average (default: 10)
* `trigger_surge::Float64`: Surge threshold in meters
* `dike_increment::Float64`: Amount to raise dike when triggered (m)
* `base_levers::Levers`: Baseline protection (other strategies)

# Example

```julia
# Raise dike by 1m whenever 10-year average surge exceeds 3m
policy = ThresholdPolicy(
    window = 10,
    trigger_surge = 3.0,
    dike_increment = 1.0,
    base_levers = Levers(0, 2, 0.5, 0, 0)  # Start with resistance
)
```

"""
struct ThresholdPolicy <: AbstractPolicy
    window::Int
    trigger_surge::Float64
    dike_increment::Float64
    base_levers::Levers

    function ThresholdPolicy(; window::Int=10,
                            trigger_surge::Real=3.0,
                            dike_increment::Real=1.0,
                            base_levers::Levers=Levers(0, 0, 0, 0, 0))
        @assert window > 0 "Window must be positive"
        @assert trigger_surge ≥ 0 "Trigger surge must be non-negative"
        @assert dike_increment > 0 "Dike increment must be positive"

        new(window, Float64(trigger_surge), Float64(dike_increment), base_levers)
    end
end

"""
    decide(policy::ThresholdPolicy, state::SimulationState) -> Levers

Check if recent surge average exceeds threshold and raise dike if so.
"""
function decide(policy::ThresholdPolicy, state::SimulationState)::Levers
    t = state.year

    # Calculate moving average of recent surges
    window_start = max(1, t - policy.window + 1)
    recent_surges = state.surge_history[window_start:t-1]  # Don't include current year

    avg_surge = isempty(recent_surges) ? 0.0 : mean(recent_surges)

    # Determine if we should raise dike
    current_dike = state.current_levers.dike_h

    new_dike = if avg_surge > policy.trigger_surge
        current_dike + policy.dike_increment
    else
        current_dike
    end

    # Return new levers (maintaining other baseline strategies)
    return Levers(
        policy.base_levers.withdraw_h,
        policy.base_levers.resist_h,
        policy.base_levers.resist_p,
        new_dike,
        policy.base_levers.dike_base_h
    )
end

# ============================================================================

# Helper Functions

# ============================================================================

"""
    create_static_policy_from_vector(x::AbstractVector) -> StaticPolicy

Convenience constructor for optimization.

Converts 5-element vector [W, R, P, D, B] into StaticPolicy.
"""
function create_static_policy_from_vector(x::AbstractVector)::StaticPolicy
    @assert length(x) == 5 "Policy vector must have 5 elements"
    return StaticPolicy(Levers(x))
end

```

---

### Phase 4: Optimization

**Goal:** Interface with Metaheuristics.jl using NSGA-II.

#### File: `src/optimization.jl`

```julia
using Metaheuristics
using Statistics

"""
    OptimizationResult

Container for multi-objective optimization results.

# Fields
- `pareto_front::Matrix{Float64}`: Pareto optimal solutions (n_solutions × 2)
  - Column 1: Mean investment cost
  - Column 2: Mean damage
- `pareto_levers::Vector{Levers}`: Corresponding lever settings
- `raw_result`: Raw Metaheuristics.jl result object
- `n_evaluations::Int`: Number of function evaluations performed
"""
struct OptimizationResult
    pareto_front::Matrix{Float64}
    pareto_levers::Vector{Levers}
    raw_result::Any
    n_evaluations::Int
end

"""
    create_objective_function(city::CityParameters, surge_matrix::AbstractMatrix{Float64})

Create objective function for multi-objective optimization.

Returns a function f(x) that:
1. Converts vector x to Levers
2. Checks feasibility
3. Simulates across all surge scenarios
4. Returns [mean_cost, mean_damage]

The objective function handles constraint violations by returning Inf.
"""
function create_objective_function(city::CityParameters,
                                   surge_matrix::AbstractMatrix{Float64})

    function objective(x::AbstractVector)::Vector{Float64}
        # Convert to Levers
        try
            levers = Levers(x; city_max_height=city.city_max_height)
        catch e
            # Constraint violation in Levers constructor
            return [Inf, Inf]
        end

        # Double-check feasibility
        if !is_feasible(levers, city)
            return [Inf, Inf]
        end

        # Create static policy
        policy = StaticPolicy(levers)

        # Simulate across all scenarios
        results = simulate_ensemble(city, policy, surge_matrix; mode=:scalar)

        # Extract costs and damages
        costs = [r.cost for r in results]
        damages = [r.damage for r in results]

        # Return mean objectives
        mean_cost = mean(costs)
        mean_damage = mean(damages)

        return [mean_cost, mean_damage]
    end

    return objective
end

"""
    optimize_portfolio(city::CityParameters,
                      surge_matrix::AbstractMatrix{Float64};
                      n_gen::Int=100,
                      pop_size::Int=200,
                      seed::Union{Int,Nothing}=nothing) -> OptimizationResult

Optimize coastal defense portfolio using NSGA-II multi-objective optimization.

# Arguments
- `city`: City parameters
- `surge_matrix`: Matrix of surge scenarios (n_scenarios × n_years)
- `n_gen`: Number of generations (default: 100)
- `pop_size`: Population size (default: 200)
- `seed`: Random seed for reproducibility (default: nothing)

# Returns
OptimizationResult containing Pareto front and corresponding strategies.

# Example
```julia
city = CityParameters()
surges = generate_surge_scenarios(city, 5000)
result = optimize_portfolio(city, surges; n_gen=100)

# Extract Pareto optimal solutions
for (i, levers) in enumerate(result.pareto_levers)
    cost, damage = result.pareto_front[i, :]
    println("Solution \$i: Cost=\$cost, Damage=\$damage")
    println("  Levers: \$levers")
end
```

"""
function optimize_portfolio(city::CityParameters,
                           surge_matrix::AbstractMatrix{Float64};
                           n_gen::Int=100,
                           pop_size::Int=200,
                           seed::Union{Int,Nothing}=nothing)::OptimizationResult

    # Set random seed if provided
    if !isnothing(seed)
        Random.seed!(seed)
    end

    # Define bounds for 5 levers [W, R, P, D, B]
    bounds = boxconstraints(
        lb = [0.0, 0.0, 0.0, 0.0, 0.0],  # Lower bounds
        ub = [
            city.city_max_height * 0.5,  # W: Max withdrawal at half city height
            city.city_max_height * 0.8,  # R: Max resistance height
            1.0,                          # P: Max resistance percentage
            15.0,                         # D: Max dike height (problem-specific)
            city.city_max_height - 3.0   # B: Max dike base (leave room for height)
        ]
    )

    # Create objective function
    f = create_objective_function(city, surge_matrix)

    # Setup NSGA-II
    options = Options(
        iterations = n_gen,
        f_calls_limit = n_gen * pop_size,
        seed = seed
    )

    algorithm = NSGA2(N = pop_size)

    # Optimize
    result = Metaheuristics.optimize(f, bounds, algorithm, options=options)

    # Extract Pareto front
    pareto_front = result.PF  # Pareto front objectives (n_solutions × 2)
    pareto_solutions = result.population[result.frontier]  # Pareto optimal solutions

    # Convert solutions to Levers
    pareto_levers = [Levers(sol.x; validate=false) for sol in pareto_solutions]

    return OptimizationResult(
        pareto_front,
        pareto_levers,
        result,
        n_gen * pop_size
    )
end

"""
    optimize_single_lever(city::CityParameters,
                         surge_matrix::AbstractMatrix{Float64},
                         lever_index::Int;
                         kwargs...) -> OptimizationResult

Optimize a single lever while holding others at zero.

Useful for replicating van Dantzig-style analysis.

# Arguments

- `lever_index`: Which lever to optimize (1=W, 2=R, 3=P, 4=D, 5=B)

# Example

```julia
# Optimize only dike height (van Dantzig emulation)
result = optimize_single_lever(city, surges, 4; n_gen=50)
```

"""
function optimize_single_lever(city::CityParameters,
                              surge_matrix::AbstractMatrix{Float64},
                              lever_index::Int;
                              kwargs...)::OptimizationResult

    @assert 1 ≤ lever_index ≤ 5 "Lever index must be 1-5"

    # Modified objective that fixes other levers to zero
    base_objective = create_objective_function(city, surge_matrix)

    function single_lever_objective(x::AbstractVector)::Vector{Float64}
        # Create full vector with zeros except for selected lever
        full_x = zeros(5)
        full_x[lever_index] = x[1]

        return base_objective(full_x)
    end

    # Single-parameter bounds
    if lever_index == 3  # Resistance percentage
        bounds = boxconstraints(lb=[0.0], ub=[1.0])
    elseif lever_index == 4  # Dike height
        bounds = boxconstraints(lb=[0.0], ub=[15.0])
    else
        bounds = boxconstraints(lb=[0.0], ub=[city.city_max_height * 0.8])
    end

    # Run optimization
    options = Options(iterations=get(kwargs, :n_gen, 100))
    algorithm = NSGA2(N=get(kwargs, :pop_size, 200))

    result = Metaheuristics.optimize(single_lever_objective, bounds, algorithm, options=options)

    # Convert back to 5-lever format
    pareto_levers = map(result.population[result.frontier]) do sol
        full_x = zeros(5)
        full_x[lever_index] = sol.x[1]
        Levers(full_x; validate=false)
    end

    return OptimizationResult(
        result.PF,
        pareto_levers,
        result,
        get(kwargs, :n_gen, 100) * get(kwargs, :pop_size, 200)
    )
end

```

---

### Phase 5: Analysis & Data

**Goal:** Forward mode analysis with YAXArrays for visualization.

#### File: `src/analysis.jl`

```julia
using YAXArrays
using DataFrames
using Statistics

"""
    run_forward_mode(city::CityParameters,
                    policy::AbstractPolicy,
                    surge_matrix::AbstractMatrix{Float64}) -> YAXArray

Run forward-mode simulation generating full time-series for all scenarios.

Creates a YAXArray with dimensions (Time × Scenario × Variable) containing:
- investment: Annual investment cost
- damage: Annual damage
- W, R, P, D, B: Lever values
- surge: Surge height

# Returns
YAXArray with axes:
- Ti: Time axis (1:n_years)
- Scenario: Scenario axis (1:n_scenarios)
- Variable: Variable names

# Example
```julia
policy = StaticPolicy(Levers(0, 2, 0.5, 5, 2))
surges = generate_surge_scenarios(city, 100)
results = run_forward_mode(city, policy, surges)

# Plot spaghetti plot of all damage trajectories
using Plots
plot(results[Variable=At("damage")]', legend=false, alpha=0.3)

# Calculate 90th percentile damage over time
p90_damage = mapslices(x -> quantile(x, 0.9), results[Variable=At("damage")], dims=:Scenario)
```

"""
function run_forward_mode(city::CityParameters,
                         policy::AbstractPolicy,
                         surge_matrix::AbstractMatrix{Float64})::YAXArray

    n_scenarios, n_years = size(surge_matrix)
    @assert n_years == city.n_years "Surge matrix years must match city.n_years"

    # Variable names
    variables = [:investment, :damage, :W, :R, :P, :D, :B, :surge]
    n_vars = length(variables)

    # Pre-allocate output array
    data = zeros(Float64, n_years, n_scenarios, n_vars)

    # Run simulation for each scenario
    for i in 1:n_scenarios
        surge_sequence = surge_matrix[i, :]
        trace = simulate(city, policy, surge_sequence; mode=:trace)

        # Fill data array
        data[:, i, 1] = trace.investment
        data[:, i, 2] = trace.damage
        data[:, i, 3] = trace.W
        data[:, i, 4] = trace.R
        data[:, i, 5] = trace.P
        data[:, i, 6] = trace.D
        data[:, i, 7] = trace.B
        data[:, i, 8] = trace.surge
    end

    # Create YAXArray with named dimensions
    yax = YAXArray(
        (Dim{:Time}(1:n_years),
         Dim{:Scenario}(1:n_scenarios),
         Dim{:Variable}(variables)),
        data
    )

    return yax
end

"""
    summarize_results(results::YAXArray) -> DataFrame

Calculate summary statistics across scenarios.

Returns DataFrame with columns:
* year: Year index
* variable: Variable name
* mean: Mean across scenarios
* median: Median across scenarios
* p10: 10th percentile
* p90: 90th percentile
* min: Minimum
* max: Maximum
"""
function summarize_results(results::YAXArray)::DataFrame
    variables = results.Variable.val
    n_years = length(results.Time)

    summaries = []

    for var in variables
        var_data = results[Variable=At(var)]  # Shape: (Time × Scenario)

        for t in 1:n_years
            time_slice = var_data[Time=At(t)][:]  # All scenarios at this time

            push!(summaries, (
                year = t,
                variable = String(var),
                mean = mean(time_slice),
                median = median(time_slice),
                p10 = quantile(time_slice, 0.1),
                p90 = quantile(time_slice, 0.9),
                min = minimum(time_slice),
                max = maximum(time_slice)
            ))
        end
    end

    return DataFrame(summaries)
end

"""
    calculate_robustness_metrics(results::OptimizationResult,
                                 surge_matrix::AbstractMatrix{Float64},
                                 city::CityParameters) -> DataFrame

Calculate robustness metrics for each Pareto optimal solution.

Returns DataFrame with:
* solution_id: Index in Pareto front
* mean_cost: Mean investment cost
* mean_damage: Mean damage
* p90_damage: 90th percentile damage (worst-case proxy)
* max_damage: Maximum damage across scenarios
* regret: Maximum regret relative to best possible
"""
function calculate_robustness_metrics(result::OptimizationResult,
                                      surge_matrix::AbstractMatrix{Float64},
                                      city::CityParameters)::DataFrame

    metrics = []

    for (i, levers) in enumerate(result.pareto_levers)
        policy = StaticPolicy(levers)

        # Simulate across all scenarios
        sim_results = simulate_ensemble(city, policy, surge_matrix; mode=:scalar)

        costs = [r.cost for r in sim_results]
        damages = [r.damage for r in sim_results]

        push!(metrics, (
            solution_id = i,
            mean_cost = mean(costs),
            mean_damage = mean(damages),
            p90_damage = quantile(damages, 0.9),
            max_damage = maximum(damages),
            std_damage = std(damages)
        ))
    end

    df = DataFrame(metrics)

  # Calculate regret (distance from best-case scenario)

    min_damage = minimum(df.mean_damage)
    df.regret = df.mean_damage .- min_damage

    return df
end

```

#### File: `src/surges.jl`

**Surge generation utilities:**

```julia
using Distributions

"""
    generate_surge_scenarios(city::CityParameters,
                            n_scenarios::Int;
                            gev_location::Float64=2.0,
                            gev_scale::Float64=0.5,
                            gev_shape::Float64=0.0,
                            trend_per_year::Float64=0.01) -> Matrix{Float64}

Generate synthetic storm surge scenarios using non-stationary GEV.

Implements the surge generation approach from Ceres et al. (2019), Section 2.1.1.

# Arguments
- `n_scenarios`: Number of 50-year scenarios to generate
- `gev_location`: Initial GEV location parameter (m)
- `gev_scale`: Initial GEV scale parameter (m)
- `gev_shape`: GEV shape parameter (ξ)
- `trend_per_year`: Annual increase in location and scale (m/year)

# Returns
Matrix of size (n_scenarios × n_years) with surge heights in meters.

Surges are capped at a maximum threshold that increases over time
(12m initial + 0.01m/year) to maintain physical plausibility.
"""
function generate_surge_scenarios(city::CityParameters,
                                  n_scenarios::Int;
                                  gev_location::Float64=2.0,
                                  gev_scale::Float64=0.5,
                                  gev_shape::Float64=0.0,
                                  trend_per_year::Float64=0.01)::Matrix{Float64}

    n_years = city.n_years
    surge_matrix = zeros(n_scenarios, n_years)

    for scenario in 1:n_scenarios
        for year in 1:n_years
            # Non-stationary parameters (increasing with time)
            μ_t = gev_location + trend_per_year * (year - 1)
            σ_t = gev_scale + trend_per_year * (year - 1)
            ξ = gev_shape

            # Generate from GEV distribution
            if abs(ξ) < 1e-6
                # Gumbel case (ξ ≈ 0)
                dist = Gumbel(μ_t, σ_t)
            else
                # General GEV
                dist = GeneralizedExtremeValue(μ_t, σ_t, ξ)
            end

            surge = rand(dist)

            # Cap at physically plausible threshold
            threshold = 12.0 + 0.01 * (year - 1)
            surge = min(surge, threshold)

            # Ensure non-negative
            surge = max(0.0, surge)

            surge_matrix[scenario, year] = surge
        end
    end

    return surge_matrix
end

"""
    generate_constant_surges(city::CityParameters,
                            surge_height::Float64) -> Matrix{Float64}

Generate scenarios with constant surge height (for testing).

Returns matrix of size (1 × n_years) with all values equal to surge_height.
"""
function generate_constant_surges(city::CityParameters,
                                  surge_height::Float64)::Matrix{Float64}
    return fill(surge_height, 1, city.n_years)
end
```

---

## Testing Strategy

**Goal:** Comprehensive testing at multiple levels.

### Unit Tests

#### File: `test/parameters_tests.jl`

```julia
@testset "CityParameters" begin
    # Default construction
    city = CityParameters()
    @test validate_parameters(city)

    # Invalid parameters
    @test_throws AssertionError CityParameters(total_value=-1000)
    @test_throws AssertionError CityParameters(discount_rate=1.5)
end

@testset "Levers Constraints" begin
    # Valid construction
    levers = Levers(2, 3, 0.5, 5, 4)
    @test is_feasible(levers, CityParameters())

    # Constraint violations
    @test_throws AssertionError Levers(10, 0, 0, 5, 2)  # W > B
    @test_throws AssertionError Levers(0, 0, 1.5, 0, 0)  # P > 1
    @test_throws AssertionError Levers(0, 0, 0, 10, 10)  # B+D > H_city
    @test_throws AssertionError Levers(0, 0, 0, -1, 0)   # Negative height
end
```

#### File: `test/geometry_tests.jl`

```julia
@testset "Dike Volume" begin
    city = CityParameters()

    # Zero height
    @test calculate_dike_volume(city, 0.0, 0.0) == 0.0

    # Monotonicity
    volumes = [calculate_dike_volume(city, D, 0.0) for D in 0:0.5:15]
    @test all(diff(volumes) .≥ 0)

    # Numerical stability
    V = calculate_dike_volume(city, 10.0, 2.0)
    @test !isnan(V) && !isinf(V) && V > 0
end
```

#### File: `test/costs_tests.jl`

```julia
@testset "Investment Costs" begin
    city = CityParameters()

    # Withdrawal cost monotonicity
    costs_W = [calculate_withdrawal_cost(city, W) for W in 0:1:10]
    @test all(diff(costs_W) .≥ 0)

    # Resistance cost increases with P
    levers_R = [Levers(0, 3, P, 0, 0) for P in 0:0.1:0.9]
    costs_R = [calculate_resistance_cost(city, l) for l in levers_R]
    @test all(diff(costs_R) .≥ 0)

    # Dike cost increases with height
    costs_D = [calculate_dike_cost(city, D, 0) for D in 0:1:15]
    @test all(diff(costs_D) .≥ 0)

    # Total cost is sum of components
    levers = Levers(2, 3, 0.5, 5, 4)
    total = calculate_investment_cost(city, levers)
    C_W = calculate_withdrawal_cost(city, 2)
    C_R = calculate_resistance_cost(city, levers)
    C_D = calculate_dike_cost(city, 5, 4)
    @test total ≈ C_W + C_R + C_D
end
```

#### File: `test/damage_tests.jl`

```julia
@testset "Damage Calculation" begin
    city = CityParameters()
    levers = Levers(0, 0, 0, 0, 0)

    # No damage below seawall
    @test calculate_event_damage_full(city, levers, city.seawall_height - 0.1) == 0.0

    # Damage monotonicity with surge height
    damages = [calculate_event_damage_full(city, levers, s) for s in 0:0.5:10]
    @test all(diff(damages) .≥ 0)

    # Resistance reduces damage
    levers_resist = Levers(0, 3, 0.5, 0, 0)
    damage_resist = calculate_event_damage_full(city, levers_resist, 3.0)
    damage_none = calculate_event_damage_full(city, levers, 3.0)
    @test damage_resist < damage_none
end
```

### Integration Tests

#### File: `test/simulation_tests.jl`

```julia
@testset "Simulation Engine" begin
    city = CityParameters()
    surges = fill(3.0, city.n_years)  # Constant surge
    policy = StaticPolicy(Levers(0, 0, 0, 5, 2))

    # Scalar mode
    result = simulate(city, policy, surges; mode=:scalar)
    @test result.cost ≥ 0
    @test result.damage ≥ 0

    # Trace mode
    trace = simulate(city, policy, surges; mode=:trace)
    @test nrow(trace) == city.n_years
    @test all(trace.year .== 1:city.n_years)

    # Irreversibility
    @test all(diff(trace.D) .≥ 0)  # Dike never decreases
end

@testset "Policy Execution" begin
    city = CityParameters()
    surges = generate_constant_surges(city, 3.0)

    # Static policy
    policy_static = StaticPolicy(Levers(0, 0, 0, 5, 2))
    result_static = simulate(city, policy_static, surges[1, :]; mode=:scalar)
    @test result_static.cost > 0  # Has investment cost

    # Dynamic threshold policy
    policy_dynamic = ThresholdPolicy(
        window=5,
        trigger_surge=2.5,
        dike_increment=1.0,
        base_levers=Levers(0, 0, 0, 0, 0)
    )
    trace_dynamic = simulate(city, policy_dynamic, surges[1, :]; mode=:trace)
    @test any(trace_dynamic.D .> 0)  # Dike eventually built
end
```

### Regression Tests

#### File: `test/van_dantzig_tests.jl`

```julia
@testset "Van Dantzig Emulation" begin
    city = CityParameters()
    surges = generate_constant_surges(city, 3.0)

    # Optimize only dike height
    result = optimize_single_lever(city, surges, 4; n_gen=50, pop_size=100)

    # Should find U-shaped cost curve
    costs = result.pareto_front[:, 1]
    damages = result.pareto_front[:, 2]
    net_costs = costs .+ damages

    # Net cost should have minimum (U-shape)
    min_idx = argmin(net_costs)
    @test min_idx > 1  # Not at zero
    @test min_idx < length(net_costs)  # Not at maximum

    # Optimal dike height should be reasonable (2-10m)
    optimal_levers = result.pareto_levers[min_idx]
    @test 2.0 ≤ optimal_levers.dike_h ≤ 10.0
end
```

#### File: `test/pareto_regression_tests.jl`

```julia
@testset "Pareto Front Shape" begin
    city = CityParameters()
    surges = generate_surge_scenarios(city, 100; trend_per_year=0.01)

    # Multi-lever optimization
    result = optimize_portfolio(city, surges; n_gen=50, pop_size=100)

    # Pareto front should be non-dominated
    PF = result.pareto_front
    n_solutions = size(PF, 1)

    for i in 1:n_solutions
        for j in 1:n_solutions
            if i != j
                # No solution should dominate another on Pareto front
                dominates = (PF[i, 1] ≤ PF[j, 1]) && (PF[i, 2] ≤ PF[j, 2])
                strictly_better = (PF[i, 1] < PF[j, 1]) || (PF[i, 2] < PF[j, 2])
                @test !(dominates && strictly_better)
            end
        end
    end

    # Cost-damage tradeoff should be visible
    costs = PF[:, 1]
    damages = PF[:, 2]

    # Negative correlation (higher investment → lower damage)
    @test cor(costs, damages) < 0
end
```

### Property-Based Tests

#### File: `test/property_tests.jl`

```julia
using Random

@testset "Property-Based Tests" begin
    city = CityParameters()

    @testset "Cost Monotonicity" begin
        # Investment cost increases with any lever increase
        for _ in 1:100
            base_levers = Levers(
                rand() * 5,
                rand() * 5,
                rand(),
                rand() * 10,
                rand() * 5
            )

            cost_base = calculate_investment_cost(city, base_levers)

            # Increase each lever and check cost increases
            for i in 1:5
                increased = [base_levers.withdraw_h, base_levers.resist_h,
                           base_levers.resist_p, base_levers.dike_h, base_levers.dike_base_h]
                increased[i] += 0.1

                try
                    new_levers = Levers(increased...)
                    cost_new = calculate_investment_cost(city, new_levers)
                    @test cost_new ≥ cost_base
                catch
                    # Skip if constraints violated
                    continue
                end
            end
        end
    end

    @testset "Irreversibility Property" begin
        # max(levers1, levers2) should have cost ≥ max(cost1, cost2)
        for _ in 1:50
            l1 = Levers(rand()*3, rand()*3, rand(), rand()*5, rand()*3)
            l2 = Levers(rand()*3, rand()*3, rand(), rand()*5, rand()*3)
            l_max = max(l1, l2)

            c1 = calculate_investment_cost(city, l1)
            c2 = calculate_investment_cost(city, l2)
            c_max = calculate_investment_cost(city, l_max)

            @test c_max ≥ max(c1, c2)
        end
    end
end
```

---

## Documentation Requirements

Before implementation begins, create these documentation files:

1. **`docs/equations.md`**
   * All equations from Ceres et al. (2019) in LaTeX
   * Equation numbers, page references
   * Variable definitions
   * **Must be completed before Phase 1b**

2. **`docs/parameters.md`**
   * Complete parameter table from Tables C.3 and C.4
   * Default values, units, physical meaning
   * **Must be completed before Phase 0**

3. **`docs/zones.md`**
   * Zone definitions from Figure 3
   * Zone interaction logic
   * Damage calculation by zone
   * **Must be completed before Phase 1c**

4. **`README.md`**
   * Project overview
   * Installation instructions
   * Quick start example
   * Link to documentation

5. **`LICENSE`**
   * GPLv3 license text

---

## Package Structure

```
ICOW.jl/
├── Project.toml
├── README.md
├── LICENSE
├── docs/
│   ├── equations.md
│   ├── parameters.md
│   ├── zones.md
│   └── figures/
│       └── (copy from paper)
├── src/
│   ├── ICOW.jl              # Main module file
│   ├── parameters.jl        # Phase 0
│   ├── types.jl             # Phase 0
│   ├── geometry.jl          # Phase 1a
│   ├── costs.jl             # Phase 1b
│   ├── damage.jl            # Phase 1b
│   ├── zones.jl             # Phase 1c
│   ├── simulation.jl        # Phase 2
│   ├── policies.jl          # Phase 3
│   ├── optimization.jl      # Phase 4
│   ├── analysis.jl          # Phase 5
│   └── surges.jl            # Phase 5
└── test/
    ├── runtests.jl
    ├── parameters_tests.jl
    ├── geometry_tests.jl
    ├── costs_tests.jl
    ├── damage_tests.jl
    ├── zones_tests.jl
    ├── simulation_tests.jl
    ├── van_dantzig_tests.jl
    ├── pareto_regression_tests.jl
    └── property_tests.jl
```

---

## Implementation Checklist

### Phase 0: Parameters & Validation

- [ ] Create `src/parameters.jl` with `CityParameters`
* [ ] Create `src/types.jl` with `Levers` and constraints
* [ ] Create `docs/parameters.md`
* [ ] Write unit tests for parameter validation
* [ ] Write unit tests for lever constraints

### Phase 1a: Geometry

- [ ] Extract Equation 6 to `docs/equations.md`
* [ ] Implement `calculate_dike_volume()` in `src/geometry.jl`
* [ ] Write unit tests for volume calculation
* [ ] Validate against hand calculations

### Phase 1b: Core Physics

- [ ] Extract Equations 1-5, 7-9 to `docs/equations.md`
* [ ] Implement cost functions in `src/costs.jl`
* [ ] Implement damage functions in `src/damage.jl`
* [ ] Write unit tests for costs
* [ ] Write unit tests for damage

### Phase 1c: Zones

- [ ] Create `docs/zones.md` from Figure 3
* [ ] Implement `calculate_city_zones()` in `src/zones.jl`
* [ ] Implement zone-based damage in `src/damage.jl`
* [ ] Write unit tests for zone calculation
* [ ] Write unit tests for zone damage

### Phase 2: Simulation

- [ ] Implement `SimulationState` in `src/simulation.jl`
* [ ] Implement `simulate()` with scalar mode
* [ ] Implement `simulate()` with trace mode
* [ ] Implement `simulate_ensemble()`
* [ ] Write simulation tests
* [ ] Test irreversibility enforcement

### Phase 3: Policies

- [ ] Implement `AbstractPolicy` interface
* [ ] Implement `StaticPolicy`
* [ ] Implement `ThresholdPolicy`
* [ ] Write policy execution tests

### Phase 4: Optimization

- [ ] Implement `create_objective_function()`
* [ ] Implement `optimize_portfolio()`
* [ ] Implement `optimize_single_lever()`
* [ ] Write van Dantzig regression test
* [ ] Write Pareto front tests

### Phase 5: Analysis

- [ ] Implement surge generation in `src/surges.jl`
* [ ] Implement `run_forward_mode()`
* [ ] Implement `summarize_results()`
* [ ] Implement `calculate_robustness_metrics()`
* [ ] Write forward mode tests

### Documentation & Release

- [ ] Complete all `docs/*.md` files
* [ ] Write `README.md` with examples
* [ ] Add GPLv3 `LICENSE` file
* [ ] Create example notebooks
* [ ] Run full test suite
* [ ] Profile performance
* [ ] Tag v0.1.0 release

---

## Notes

* **Equation Verification:** All equations must be manually verified against the paper before implementation
* **Testing First:** Write tests before implementation where possible
* **Documentation:** Document as you go - don't leave it for the end
* **Performance:** Profile before optimizing - clarity first
* **Git Workflow:** Commit after each phase completion
* **Dependencies:** Minimize external dependencies; prefer Base Julia where possible

---

**End of Specification**
