# Cost functions for the iCOW model
# Implements Equations 1-7 from docs/equations.md

"""
    calculate_withdrawal_cost(city::CityParameters, W) -> cost

Calculate withdrawal cost (Equation 1). See docs/equations.md.
"""
function calculate_withdrawal_cost(city::CityParameters{T}, W::Real) where {T}
    # W < H_city; full withdrawal causes division by zero
    @assert W < city.H_city "W must be strictly less than H_city to avoid division by zero"

    # Equation 1: C_W = (V_city * W * f_w) / (H_city - W)
    return city.V_city * W * city.f_w / (city.H_city - W)
end

"""
    calculate_value_after_withdrawal(city::CityParameters, W) -> value

Calculate city value remaining after withdrawal (Equation 2). See docs/equations.md.
"""
function calculate_value_after_withdrawal(city::CityParameters{T}, W::Real) where {T}
    # Equation 2: V_w = V_city * (1 - f_l * W / H_city)
    loss_fraction = city.f_l * W / city.H_city
    return city.V_city * (one(T) - loss_fraction)
end

"""
    calculate_resistance_cost_fraction(city::CityParameters, P) -> fraction

Calculate unitless resistance cost fraction (Equation 3). See docs/equations.md.
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

Calculate flood-proofing cost (Equations 4-5). See docs/equations.md.
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
        # Eq 4: C_R = (V_w * f_cR * R * (R/2 + b)) / (H_bldg * (H_city - W))
        numerator = V_w * f_cR * levers.R * (levers.R / 2 + city.b_basement)
    else
        # R >= B is dominated: protection capped at B but costs still increase with R
        if levers.R > levers.B && levers.B > zero(T)
            @warn "R > B is a dominated strategy: protection is capped at B but costs increase with R" maxlog=1
        end
        # Eq 5: C_R = (V_w * f_cR * B * (R - B/2 + b)) / (H_bldg * (H_city - W))
        numerator = V_w * f_cR * levers.B * (levers.R - levers.B / 2 + city.b_basement)
    end

    return numerator / denominator
end

"""
    calculate_dike_cost(city::CityParameters, D) -> cost

Calculate dike construction cost (Equation 7). See docs/equations.md.
"""
function calculate_dike_cost(city::CityParameters{T}, D::Real) where {T}
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

Calculate total investment cost (sum of withdrawal, resistance, dike costs).
"""
function calculate_investment_cost(city::CityParameters, levers::Levers)
    C_W = calculate_withdrawal_cost(city, levers.W)
    C_R = calculate_resistance_cost(city, levers)
    C_D = calculate_dike_cost(city, levers.D)

    return C_W + C_R + C_D
end

"""
    calculate_effective_surge(h_raw, city::CityParameters) -> h_effective

Calculate effective surge after seawall and runup. See docs/equations.md.
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

Calculate dike failure probability (Equation 8). See docs/equations.md.
h_surge should be surge height above dike base: h_at_dike = max(0, h_eff - (W+B)).
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
