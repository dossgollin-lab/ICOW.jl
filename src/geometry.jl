# Dike geometry calculations for the iCOW model
# Simplified geometric formula replacing unstable Equation 6 (see docs/equations.md)

"""
    calculate_dike_volume(city::CityParameters, D) -> volume

Calculate dike material volume using simplified geometric formula.
Replaces paper's Equation 6 which is numerically unstable. See docs/equations.md.
"""
function calculate_dike_volume(city::Core.CityParameters{T}, D::Real) where {T}
    # Effective height includes startup costs
    h_d = D + city.D_startup

    # Slopes
    s = city.s_dike                   # dike side slope (0.5)
    S = city.H_city / city.D_city     # city terrain slope (0.0085)

    # Cross-section width addition from dike slope: h/s²
    slope_width = h_d / (s * s)

    # Main seawall: trapezoidal prism along coastline
    # V = length × height × (top_width + slope_width)
    V_main = city.W_city * h_d * (city.w_d + slope_width)

    # Side wings: two tapered prisms running inland up the city slope
    # Derived by integrating dike cross-section from coast to point where ground = dike height
    # V_wings = (h²/S) × (w_d + (2/3) × h/s²)
    V_wings = (h_d * h_d / S) * (city.w_d + (T(2) / T(3)) * slope_width)

    return V_main + V_wings
end
