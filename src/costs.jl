# Cost functions for the iCOW model
# Implements Equations 1-7 from docs/equations.md

"""
    calculate_withdrawal_cost(city::CityParameters, W) -> cost

Calculate the cost of withdrawing from elevation 0 to W.

Based on Equation 1 from Ceres et al. (2019). The cost represents the expense
of relocating infrastructure from the lowest elevations of the city.

# Arguments
- `city`: City parameters containing V_city, H_city, f_w
- `W`: Withdrawal height (m) - absolute elevation

# Returns
- Withdrawal cost in dollars

# Equation
\$\$C_W = \\frac{V_{city} \\cdot W \\cdot f_w}{H_{city} - W}\$\$

# Notes
- When W = 0, cost is 0 (no withdrawal)
- Cost approaches infinity as W → H_city (denominator → 0)
- Optimization bounds should enforce W < 0.999 * H_city
"""
function calculate_withdrawal_cost(city::CityParameters{T}, W::Real) where {T}
    # When W = 0, no withdrawal occurs, so cost is 0
    if W == zero(T)
        return zero(T)
    end

    # Equation 1: C_W = (V_city * W * f_w) / (H_city - W)
    numerator = city.V_city * W * city.f_w
    denominator = city.H_city - W

    return numerator / denominator
end

"""
    calculate_value_after_withdrawal(city::CityParameters, W) -> value

Calculate the city value remaining after withdrawal from elevation 0 to W.

Based on Equation 2 from Ceres et al. (2019). This value is used in resistance
and zone calculations.

# Arguments
- `city`: City parameters containing V_city, H_city, f_l
- `W`: Withdrawal height (m) - absolute elevation

# Returns
- Remaining city value in dollars

# Equation
\$\$V_w = V_{city} \\cdot \\left(1 - \\frac{f_l \\cdot W}{H_{city}}\\right)\$\$

# Notes
- When W = 0, V_w = V_city (full value remains)
- f_l represents the fraction that leaves vs relocates
"""
function calculate_value_after_withdrawal(city::CityParameters{T}, W::Real) where {T}
    # Equation 2: V_w = V_city * (1 - f_l * W / H_city)
    loss_fraction = city.f_l * W / city.H_city
    return city.V_city * (one(T) - loss_fraction)
end

"""
    calculate_resistance_cost_fraction(city::CityParameters, P) -> fraction

Calculate the unitless resistance cost fraction f_cR.

Based on Equation 3 from Ceres et al. (2019). This fraction includes both
linear and exponential components and is multiplied by other terms to get
the total resistance cost.

# Arguments
- `city`: City parameters containing f_adj, f_lin, f_exp, t_exp
- `P`: Resistance percentage [0, 1)

# Returns
- Resistance cost fraction (unitless)

# Equation
\$\$f_{cR} = f_{adj} \\cdot \\left( f_{lin} \\cdot P + \\frac{f_{exp} \\cdot \\max(0, P - t_{exp})}{1 - P} \\right)\$\$

# Notes
- Division by (1 - P) requires P < 1.0 to avoid infinity
- Optimization bounds should enforce P < 0.999
- f_adj = 1.25 is in C++ code but not prominently in paper
- Exponential term only applies when P > t_exp
"""
function calculate_resistance_cost_fraction(city::CityParameters{T}, P::Real) where {T}
    # Linear component
    linear_term = city.f_lin * P

    # Exponential component (only applies when P > t_exp)
    exponential_numerator = city.f_exp * max(zero(T), P - city.t_exp)
    exponential_term = exponential_numerator / (one(T) - P)

    # Equation 3: f_cR = f_adj * (linear + exponential)
    return city.f_adj * (linear_term + exponential_term)
end

"""
    calculate_resistance_cost(city::CityParameters, levers::Levers) -> cost

Calculate the cost of flood-proofing (resistance).

Based on Equations 4-5 from Ceres et al. (2019). Uses the unconstrained
formula (Equation 4) when R < B, and the constrained formula (Equation 5)
when R ≥ B.

# Arguments
- `city`: City parameters
- `levers`: Decision levers containing W, R, P, B

# Returns
- Resistance cost in dollars

# Equations
Unconstrained (R < B):
\$\$C_R = \\frac{V_w \\cdot f_{cR} \\cdot R \\cdot (R/2 + b)}{H_{bldg} \\cdot (H_{city} - W)}\$\$

Constrained (R ≥ B):
\$\$C_R = \\frac{V_w \\cdot f_{cR} \\cdot B \\cdot (R - B/2 + b)}{H_{bldg} \\cdot (H_{city} - W)}\$\$

# Notes
- R ≥ B is a dominated strategy (costs more, no extra protection)
- Both R and B are relative to W
- V_w is the value after withdrawal (Equation 2)
- When R = P = 0, cost is 0 (no resistance)
"""
function calculate_resistance_cost(city::CityParameters{T}, levers::Levers{T}) where {T}
    # When no resistance is applied, cost is 0
    if levers.R == zero(T) && levers.P == zero(T)
        return zero(T)
    end

    # Get value after withdrawal and cost fraction
    V_w = calculate_value_after_withdrawal(city, levers.W)
    f_cR = calculate_resistance_cost_fraction(city, levers.P)

    # Common denominator for both equations
    denominator = city.H_bldg * (city.H_city - levers.W)

    # Choose equation based on whether resistance is constrained by dike base
    if levers.R < levers.B
        # Unconstrained: Equation 4
        # C_R = (V_w * f_cR * R * (R/2 + b)) / (H_bldg * (H_city - W))
        numerator = V_w * f_cR * levers.R * (levers.R / 2 + city.b_basement)
    else
        # Constrained: Equation 5
        # C_R = (V_w * f_cR * B * (R - B/2 + b)) / (H_bldg * (H_city - W))
        numerator = V_w * f_cR * levers.B * (levers.R - levers.B / 2 + city.b_basement)
    end

    return numerator / denominator
end

"""
    calculate_dike_cost(city::CityParameters, D, B) -> cost

Calculate the cost of building a dike of height D.

Based on Equation 7 from Ceres et al. (2019). Uses the dike volume
calculation from Phase 3 (geometry.jl).

# Arguments
- `city`: City parameters containing c_d (cost per unit volume)
- `D`: Dike height (m) - relative to dike base
- `B`: Dike base height (m) - relative to W (not used in calculation, for consistency)

# Returns
- Dike cost in dollars

# Equation
\$\$C_D = V_d \\cdot c_d\$\$

# Notes
- When D = 0 (no dike), cost is 0
- When D > 0, D_startup adds fixed costs via calculate_dike_volume
- B parameter included for API consistency but not used in calculation
"""
function calculate_dike_cost(city::CityParameters{T}, D::Real, B::Real) where {T}
    # If not building a dike, no cost
    if D == zero(T)
        return zero(T)
    end

    # Equation 7: C_D = V_d * c_d
    # D_startup is included in the volume calculation
    V_d = calculate_dike_volume(city, D)
    return V_d * city.c_d
end

"""
    calculate_investment_cost(city::CityParameters, levers::Levers) -> cost

Calculate the total investment cost for all protection measures.

Sums the costs of withdrawal, resistance, and dike construction.

# Arguments
- `city`: City parameters
- `levers`: Decision levers (W, R, P, D, B)

# Returns
- Total investment cost in dollars

# Equation
\$\$C_{total} = C_W + C_R + C_D\$\$

# Notes
- This is the upfront cost component of the objective function
- Does not include damage costs (those come from simulation)
"""
function calculate_investment_cost(city::CityParameters, levers::Levers)
    C_W = calculate_withdrawal_cost(city, levers.W)
    C_R = calculate_resistance_cost(city, levers)
    C_D = calculate_dike_cost(city, levers.D, levers.B)

    return C_W + C_R + C_D
end

"""
    calculate_effective_surge(h_raw, city::CityParameters) -> h_effective

Calculate effective surge height after accounting for seawall and runup.

Based on the surge preprocessing equations from docs/equations.md (lines 120-127).
This is the surge height used in all damage calculations.

# Arguments
- `h_raw`: Raw ocean surge height (m)
- `city`: City parameters containing H_seawall and f_runup

# Returns
- Effective surge height (m)

# Equation
\$\$h_{eff} = \\begin{cases}
0 & \\text{if } h_{raw} \\leq H_{seawall} \\\\
h_{raw} \\cdot f_{runup} - H_{seawall} & \\text{if } h_{raw} > H_{seawall}
\\end{cases}\$\$

# Notes
- f_runup = 1.1 amplifies surge due to wave runup
- Seawall provides protection up to H_seawall
- When h_raw ≤ H_seawall, no flooding occurs (h_eff = 0)
"""
function calculate_effective_surge(h_raw::Real, city::CityParameters{T}) where {T}
    if h_raw <= city.H_seawall
        return zero(T)
    else
        return h_raw * city.f_runup - city.H_seawall
    end
end

"""
    calculate_dike_failure_probability(h_surge, D, city::CityParameters) -> probability

Calculate the probability that a dike of height D fails given surge height h_surge.

Based on Equation 8 from Ceres et al. (2019), using the corrected piecewise
form (NOT the buggy paper version).

# Arguments
- `h_surge`: Effective surge height (m) - use calculate_effective_surge first
- `D`: Dike height (m) - relative to dike base
- `city`: City parameters containing t_fail and p_min

# Returns
- Failure probability [0, 1]

# Equation
\$\$p_{fail} = \\begin{cases}
p_{min} & \\text{if } h_{surge} < t_{fail} \\cdot D \\\\
\\frac{h_{surge} - t_{fail} \\cdot D}{D(1 - t_{fail})} & \\text{if } t_{fail} \\cdot D \\leq h_{surge} < D \\\\
1.0 & \\text{if } h_{surge} \\geq D
\\end{cases}\$\$

# Notes
- p_min is the base failure probability even for low surges
- t_fail = 0.95 is the threshold where failure risk begins to rise
- When D = 0 (no dike), any positive surge causes certain failure
- h_surge should be effective surge, not raw surge
"""
function calculate_dike_failure_probability(h_surge::Real, D::Real, city::CityParameters{T}) where {T}
    # Special case: no dike means certain failure if surge > 0
    if D == zero(T)
        return h_surge > zero(T) ? one(T) : city.p_min
    end

    # Calculate threshold where failure probability starts to rise
    threshold = city.t_fail * D

    # Piecewise function (corrected form)
    if h_surge < threshold
        # Below threshold: minimum failure probability
        return city.p_min
    elseif h_surge < D
        # Linear rise region: t_fail * D ≤ h_surge < D
        # p_fail = (h_surge - t_fail * D) / (D * (1 - t_fail))
        numerator = h_surge - threshold
        denominator = D * (one(T) - city.t_fail)
        return numerator / denominator
    else
        # Above dike: certain failure
        return one(T)
    end
end
