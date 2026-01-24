# Pure numeric geometry functions for the iCOW model
# Simplified geometric formula replacing unstable Equation 6 (see _background/equations.md)

"""
    dike_volume(H_city, D_city, D_startup, s_dike, w_d, W_city, D)

Calculate dike material volume using simplified geometric formula.
Replaces paper's Equation 6 which is numerically unstable. See _background/equations.md.
"""
function dike_volume(
    H_city::T, D_city::T, D_startup::T, s_dike::T, w_d::T, W_city::T, D::T
) where {T<:AbstractFloat}
    # Effective height includes startup costs
    h_d = D + D_startup

    # Slopes
    s = s_dike                    # dike side slope (0.5)
    S = H_city / D_city           # city terrain slope (0.0085)

    # Cross-section width addition from dike slope: h/s²
    slope_width = h_d / (s * s)

    # Main seawall: trapezoidal prism along coastline
    V_main = W_city * h_d * (w_d + slope_width)

    # Side wings: two tapered prisms running inland up the city slope
    V_wings = (h_d * h_d / S) * (w_d + (T(2) / T(3)) * slope_width)

    return V_main + V_wings
end
