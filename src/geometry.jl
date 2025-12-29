# Dike geometry calculations for the iCOW model

"""
    calculate_dike_volume(city::CityParameters, D) -> volume

Calculate the volume of dike material needed for a dike of height D.

Based on the C++ reference code. Note: The C++ code has an integer division bug
where `pow(T, 1/2)` evaluates to `pow(T, 0) = 1` because 1/2 = 0 in C integer
division. This means the complex tetrahedron correction term is effectively
ignored, and the formula simplifies to the main volume terms plus a constant 1/6.

The total effective height includes startup costs: ch = D + D_startup.

# Arguments
- `city`: City parameters containing geometry (W_city, s_dike, w_d, D_startup)
- `D`: Dike height in meters (relative to dike base)

# Returns
- Volume in cubic meters (m³)
"""
function calculate_dike_volume(city::CityParameters{R}, D::Real) where {R}
    # Cost height is the dike height plus the equivalent height for startup costs
    ch = D + city.D_startup

    # Shorthand for readability
    sd = city.s_dike      # dike side slope
    wdt = city.w_d        # dike top width
    W = city.W_city       # coastline length

    # Note: The C++ code uses CityLength/CityWidth (= W_city/D_city) for the slope,
    # NOT H_city/D_city as stated in the paper.
    S = city.W_city / city.D_city

    # Precompute common terms
    sd2 = sd * sd
    S2 = S * S
    ch2 = ch * ch

    # Dike volume formula (matching C++ behavior):
    # V_d = W*ch*(wdt + ch/sd^2) + 1/6 + W*ch^2/S^2
    #
    # The 1/6 comes from the C++ bug where pow(T, 1/2) = pow(T, 0) = 1 due to
    # integer division, making the tetrahedron correction term just 1/6.
    V_d = W * ch * (wdt + ch / sd2) + one(R) / 6 + W * ch2 / S2

    return V_d
end
