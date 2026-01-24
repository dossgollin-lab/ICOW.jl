# Pure numeric cost functions for the iCOW model
# Implements Equations 1-8 from _background/equations.md

"""
    withdrawal_cost(V_city, H_city, f_w, W)

Calculate withdrawal cost (Equation 1). See _background/equations.md.
"""
function withdrawal_cost(V_city, H_city, f_w, W)
    @assert W < H_city "W must be strictly less than H_city to avoid division by zero"
    return V_city * W * f_w / (H_city - W)
end

"""
    value_after_withdrawal(V_city, H_city, f_l, W)

Calculate city value remaining after withdrawal (Equation 2). See _background/equations.md.
"""
function value_after_withdrawal(V_city, H_city, f_l, W)
    loss_fraction = f_l * W / H_city
    return V_city * (one(loss_fraction) - loss_fraction)
end

"""
    resistance_cost_fraction(f_adj, f_lin, f_exp, t_exp, P)

Calculate unitless resistance cost fraction (Equation 3). See _background/equations.md.
"""
function resistance_cost_fraction(f_adj, f_lin, f_exp, t_exp, P)
    T = typeof(P)
    linear_term = f_lin * P
    exponential_numerator = f_exp * max(zero(T), P - t_exp)
    exponential_term = exponential_numerator / (one(T) - P)
    return f_adj * (linear_term + exponential_term)
end

"""
    resistance_cost(V_w, f_cR, H_bldg, H_city, W, R, B, b_basement)

Calculate flood-proofing cost (Equations 4-5). See _background/equations.md.
V_w is value after withdrawal, f_cR is resistance cost fraction.
"""
function resistance_cost(V_w, f_cR, H_bldg, H_city, W, R, B, b_basement)
    T = typeof(V_w)
    denominator = H_bldg * (H_city - W)

    if R < B
        # Eq 4: C_R = (V_w * f_cR * R * (R/2 + b)) / (H_bldg * (H_city - W))
        numerator = V_w * f_cR * R * (R / 2 + b_basement)
    else
        # Eq 5: C_R = (V_w * f_cR * B * (R - B/2 + b)) / (H_bldg * (H_city - W))
        numerator = V_w * f_cR * B * (R - B / 2 + b_basement)
    end

    return numerator / denominator
end

"""
    dike_cost(V_dike, c_d)

Calculate dike construction cost (Equation 7). See _background/equations.md.
"""
function dike_cost(V_dike, c_d)
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
h_surge should be surge height above dike base.
"""
function dike_failure_probability(h_surge, D, t_fail, p_min)
    T = typeof(h_surge)

    # No dike means certain failure if surge > 0
    if D == zero(T)
        return h_surge > zero(T) ? one(T) : p_min
    end

    threshold = t_fail * D

    if h_surge < threshold
        return p_min
    elseif h_surge < D
        numerator = h_surge - threshold
        denominator = D * (one(T) - t_fail)
        return numerator / denominator
    else
        return one(T)
    end
end
