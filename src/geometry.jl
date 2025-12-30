# Dike geometry calculations for the iCOW model
# Implements Equation 6 from docs/equations.md

"""
    calculate_dike_volume(city::CityParameters, D) -> volume

Calculate dike material volume (Equation 6). See docs/equations.md.
"""
function calculate_dike_volume(city::CityParameters{R}, D::Real) where {R}
    # Effective height includes startup costs
    h_d = D + city.D_startup

    # Shorthand
    s = city.s_dike       # dike side slope
    w_d = city.w_d        # dike top width
    W = city.W_city       # coastline length
    S = city.W_city / city.D_city  # city slope (C++ definition, see equations.md)

    # Precompute powers
    s2 = s * s
    S2 = S * S
    S4 = S2 * S2
    h_d2 = h_d * h_d
    h_d3 = h_d2 * h_d
    h_d4 = h_d3 * h_d
    h_d5 = h_d4 * h_d
    h_d6 = h_d5 * h_d

    # Tetrahedron correction term T (Equation 6)
    h_plus_inv_s = h_d + one(R) / s
    term1 = -h_d4 * h_plus_inv_s^2 / s2
    term2 = -2 * h_d5 * h_plus_inv_s / S4
    term3 = -4 * h_d6 / (s2 * S4)
    term4 = 4 * h_d4 * (2 * h_d * h_plus_inv_s - 3 * h_d2 / s2) / (s2 * S2)
    term5 = 2 * h_d3 * h_plus_inv_s / S2
    T = term1 + term2 + term3 + term4 + term5

    # Dike volume (Equation 6)
    # V_d = W_city * h_d * (w_d + h_d/s²) + (1/6)*sqrt(T) + w_d * h_d²/S²
    sqrt_T = T >= zero(R) ? sqrt(T) : zero(R)  # Guard against numerical issues
    V_d = W * h_d * (w_d + h_d / s2) + sqrt_T / 6 + w_d * h_d2 / S2

    return V_d
end
