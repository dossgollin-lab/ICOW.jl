# Pure numeric cost functions for the iCOW model
# Implements Equations 1-8 from _background/equations.md

# =============================================================================
# Pure numeric functions (take individual parameters, not structs)
# =============================================================================

"""
    withdrawal_cost(V_city, H_city, f_w, W)

Calculate withdrawal cost (Equation 1). See _background/equations.md.
"""
function withdrawal_cost(V_city, H_city, f_w, W)
    # W < H_city; full withdrawal causes division by zero
    @assert W < H_city "W must be strictly less than H_city to avoid division by zero"

    # Equation 1: C_W = (V_city * W * f_w) / (H_city - W)
    return V_city * W * f_w / (H_city - W)
end

"""
    value_after_withdrawal(V_city, H_city, f_l, W)

Calculate city value remaining after withdrawal (Equation 2). See _background/equations.md.
"""
function value_after_withdrawal(V_city, H_city, f_l, W)
    # Equation 2: V_w = V_city * (1 - f_l * W / H_city)
    loss_fraction = f_l * W / H_city
    return V_city * (one(loss_fraction) - loss_fraction)
end

"""
    resistance_cost_fraction(f_adj, f_lin, f_exp, t_exp, P)

Calculate unitless resistance cost fraction (Equation 3). See _background/equations.md.
"""
function resistance_cost_fraction(f_adj, f_lin, f_exp, t_exp, P)
    T = typeof(P)

    # Linear component
    linear_term = f_lin * P

    # Exponential component (only applies when P > t_exp)
    exponential_numerator = f_exp * max(zero(T), P - t_exp)
    exponential_term = exponential_numerator / (one(T) - P)

    # Equation 3: f_cR = f_adj * (linear + exponential)
    return f_adj * (linear_term + exponential_term)
end

"""
    resistance_cost(V_w, f_cR, H_bldg, H_city, W, R, B, b_basement)

Calculate flood-proofing cost (Equations 4-5). See _background/equations.md.
V_w is value after withdrawal, f_cR is resistance cost fraction.
"""
function resistance_cost(V_w, f_cR, H_bldg, H_city, W, R, B, b_basement)
    T = typeof(V_w)

    # When no resistance is applied, cost is 0
    if R == zero(T) && f_cR == zero(T)
        return zero(T)
    end

    # Common denominator for both equations
    denominator = H_bldg * (H_city - W)

    # Choose equation based on whether resistance is constrained by dike base
    if R < B
        # Eq 4: C_R = (V_w * f_cR * R * (R/2 + b)) / (H_bldg * (H_city - W))
        numerator = V_w * f_cR * R * (R / 2 + b_basement)
    else
        # R >= B is dominated: protection capped at B but costs still increase with R
        if R > B && B > zero(T)
            @warn "R > B is a dominated strategy: protection is capped at B but costs increase with R" maxlog=1
        end
        # Eq 5: C_R = (V_w * f_cR * B * (R - B/2 + b)) / (H_bldg * (H_city - W))
        numerator = V_w * f_cR * B * (R - B / 2 + b_basement)
    end

    return numerator / denominator
end

"""
    dike_cost(V_dike, c_d)

Calculate dike construction cost (Equation 7). See _background/equations.md.
V_dike is dike volume from geometry.jl.
"""
function dike_cost(V_dike, c_d)
    # Equation 7: C_D = V_d * c_d
    return V_dike * c_d
end

"""
    effective_surge(h_raw, H_seawall, f_runup)

Calculate effective surge after seawall and runup. See _background/equations.md.
"""
function effective_surge(h_raw, H_seawall, f_runup)
    T = typeof(h_raw)
    if h_raw <= H_seawall
        return zero(T)
    else
        return h_raw * f_runup - H_seawall
    end
end

"""
    dike_failure_probability(h_surge, D, t_fail, p_min)

Calculate dike failure probability (Equation 8). See _background/equations.md.
h_surge should be surge height above dike base: h_at_dike = max(0, h_eff - (W+B)).
"""
function dike_failure_probability(h_surge, D, t_fail, p_min)
    T = typeof(h_surge)

    # Special case: no dike means certain failure if surge > 0
    if D == zero(T)
        return h_surge > zero(T) ? one(T) : p_min
    end

    # Calculate threshold where failure probability starts to rise
    threshold = t_fail * D

    # Piecewise function (corrected form)
    if h_surge < threshold
        # Below threshold: minimum failure probability
        return p_min
    elseif h_surge < D
        # Linear rise region: t_fail * D ≤ h_surge < D
        # p_fail = (h_surge - t_fail * D) / (D * (1 - t_fail))
        numerator = h_surge - threshold
        denominator = D * (one(T) - t_fail)
        return numerator / denominator
    else
        # Above dike: certain failure
        return one(T)
    end
end

# =============================================================================
# Convenience wrappers that take CityParameters and Levers
# =============================================================================

"""
    withdrawal_cost(city::CityParameters, W) -> cost

Calculate withdrawal cost. Wrapper for pure numeric function.
"""
function withdrawal_cost(city::CityParameters, W)
    return withdrawal_cost(city.V_city, city.H_city, city.f_w, W)
end

"""
    value_after_withdrawal(city::CityParameters, W) -> value

Calculate value after withdrawal. Wrapper for pure numeric function.
"""
function value_after_withdrawal(city::CityParameters, W)
    return value_after_withdrawal(city.V_city, city.H_city, city.f_l, W)
end

"""
    resistance_cost_fraction(city::CityParameters, P) -> fraction

Calculate resistance cost fraction. Wrapper for pure numeric function.
"""
function resistance_cost_fraction(city::CityParameters, P)
    return resistance_cost_fraction(city.f_adj, city.f_lin, city.f_exp, city.t_exp, P)
end

"""
    resistance_cost(city::CityParameters, levers::Levers) -> cost

Calculate resistance cost. Wrapper for pure numeric function.
"""
function resistance_cost(city::CityParameters{T}, levers::Levers{T}) where {T}
    # When no resistance is applied, cost is 0
    if levers.R == zero(T) && levers.P == zero(T)
        return zero(T)
    end

    # Get value after withdrawal and cost fraction
    V_w = value_after_withdrawal(city, levers.W)
    f_cR = resistance_cost_fraction(city, levers.P)

    return resistance_cost(
        V_w, f_cR, city.H_bldg, city.H_city,
        levers.W, levers.R, levers.B, city.b_basement
    )
end

"""
    dike_cost(city::CityParameters, D) -> cost

Calculate dike cost. Wrapper for pure numeric function.
"""
function dike_cost(city::CityParameters{T}, D) where {T}
    # If not building a dike, no cost
    if D == zero(T)
        return zero(T)
    end

    V_d = dike_volume(city, D)
    return dike_cost(V_d, city.c_d)
end

"""
    investment_cost(city::CityParameters, levers::Levers) -> cost

Calculate total investment cost (sum of withdrawal, resistance, dike costs).
"""
function investment_cost(city::CityParameters, levers::Levers)
    C_W = withdrawal_cost(city, levers.W)
    C_R = resistance_cost(city, levers)
    C_D = dike_cost(city, levers.D)

    return C_W + C_R + C_D
end

"""
    effective_surge(h_raw, city::CityParameters) -> h_effective

Calculate effective surge. Wrapper for pure numeric function.
"""
function effective_surge(h_raw, city::CityParameters)
    return effective_surge(h_raw, city.H_seawall, city.f_runup)
end

"""
    dike_failure_probability(h_surge, D, city::CityParameters) -> probability

Calculate dike failure probability. Wrapper for pure numeric function.
"""
function dike_failure_probability(h_surge, D, city::CityParameters)
    return dike_failure_probability(h_surge, D, city.t_fail, city.p_min)
end
