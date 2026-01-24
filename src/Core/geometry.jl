# Pure numeric geometry functions for the iCOW model
# Simplified geometric formula replacing unstable Equation 6 (see _background/equations.md)

"""
    dike_volume(H_city, D_city, D_startup, s_dike, w_d, W_city, D)

Calculate dike material volume using simplified geometric formula.
Replaces paper's Equation 6 which is numerically unstable. See _background/equations.md.

Pure numeric function - takes individual parameters, not structs.
"""
function dike_volume(H_city, D_city, D_startup, s_dike, w_d, W_city, D)
    # Effective height includes startup costs
    h_d = D + D_startup

    # Slopes
    s = s_dike                    # dike side slope (0.5)
    S = H_city / D_city           # city terrain slope (0.0085)

    # Cross-section width addition from dike slope: h/s²
    slope_width = h_d / (s * s)

    # Main seawall: trapezoidal prism along coastline
    # V = length × height × (top_width + slope_width)
    V_main = W_city * h_d * (w_d + slope_width)

    # Side wings: two tapered prisms running inland up the city slope
    # Derived by integrating dike cross-section from coast to point where ground = dike height
    # V_wings = (h²/S) × (w_d + (2/3) × h/s²)
    T = typeof(h_d)
    V_wings = (h_d * h_d / S) * (w_d + (T(2) / T(3)) * slope_width)

    return V_main + V_wings
end

# Convenience wrapper that takes CityParameters
"""
    dike_volume(city::CityParameters, D) -> volume

Calculate dike material volume. Wrapper for pure numeric function.
"""
function dike_volume(city::CityParameters, D)
    return dike_volume(
        city.H_city, city.D_city, city.D_startup,
        city.s_dike, city.w_d, city.W_city, D
    )
end
