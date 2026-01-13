# Parameters for the iCOW (Island City on a Wedge) model
# All defaults from docs/equations.md (C++ values where paper differs)

"""
    CityParameters{T<:Real} <: SimOptDecisions.AbstractConfig

Exogenous parameters for the iCOW coastal flood model.
See docs/equations.md for full parameter documentation.
"""
Base.@kwdef struct CityParameters{T<:Real} <: SimOptDecisions.AbstractConfig
    # Geometry (6)
    V_city::T = 1.5e12      # Initial city value ($)
    H_bldg::T = 30.0        # Building height (m)
    H_city::T = 17.0        # City max elevation (m)
    D_city::T = 2000.0      # City depth from seawall to peak (m)
    W_city::T = 43000.0     # City coastline length (m)
    H_seawall::T = 1.75     # Seawall height (m)

    # Dike (4)
    D_startup::T = 2.0      # Startup height for fixed costs (m)
    w_d::T = 3.0            # Dike top width (m)
    s_dike::T = 0.5         # Dike side slope (horizontal/vertical)
    c_d::T = 10.0           # Dike cost per volume ($/m^3)

    # Zones (2)
    r_prot::T = 1.1         # Protected zone value ratio
    r_unprot::T = 0.95      # Unprotected zone value ratio

    # Withdrawal (2)
    f_w::T = 1.0            # Withdrawal cost factor
    f_l::T = 0.01           # Loss fraction (leaves vs relocates)

    # Resistance (5)
    f_adj::T = 1.25         # Adjustment factor (hidden in C++ code)
    f_lin::T = 0.35         # Linear cost factor
    f_exp::T = 0.115        # Exponential cost factor
    t_exp::T = 0.4          # Exponential threshold
    b_basement::T = 3.0     # Basement depth (m)

    # Damage (6)
    f_damage::T = 0.39      # Fraction of value lost per flood
    f_intact::T = 0.03      # Damage factor when dike holds
    f_failed::T = 1.5       # Damage factor when dike fails
    t_fail::T = 0.95        # Surge/height ratio for failure onset
    p_min::T = 0.05         # Minimum dike failure probability
    f_runup::T = 1.1        # Wave runup amplification factor

    # Threshold (3)
    d_thresh::T = 4.0e9     # Damage threshold ($), default = V_city/375
    f_thresh::T = 1.0       # Threshold fraction multiplier
    gamma_thresh::T = 1.01  # Threshold exponent
end

"""
    validate_parameters(city::CityParameters)

Validate physical bounds on city parameters. Throws AssertionError if violated.
"""
function validate_parameters(city::CityParameters)
    # Positive values (must be > 0)
    @assert city.V_city > 0 "V_city must be positive"
    @assert city.H_bldg > 0 "H_bldg must be positive"
    @assert city.H_city > 0 "H_city must be positive"
    @assert city.D_city > 0 "D_city must be positive"
    @assert city.W_city > 0 "W_city must be positive"
    @assert city.s_dike > 0 "s_dike must be positive"

    # Non-negative values (>= 0)
    @assert city.H_seawall >= 0 "H_seawall must be non-negative"
    @assert city.D_startup >= 0 "D_startup must be non-negative"
    @assert city.w_d >= 0 "w_d must be non-negative"
    @assert city.c_d >= 0 "c_d must be non-negative"
    @assert city.b_basement >= 0 "b_basement must be non-negative"
    @assert city.d_thresh >= 0 "d_thresh must be non-negative"

    # Fractions in [0, 1]
    @assert 0 <= city.f_l <= 1 "f_l must be in [0, 1]"
    @assert 0 <= city.f_damage <= 1 "f_damage must be in [0, 1]"
    @assert 0 <= city.t_fail <= 1 "t_fail must be in [0, 1]"
    @assert 0 <= city.p_min <= 1 "p_min must be in [0, 1]"
    @assert 0 <= city.t_exp <= 1 "t_exp must be in [0, 1]"

    # Positive multipliers
    @assert city.f_w > 0 "f_w must be positive"
    @assert city.f_adj > 0 "f_adj must be positive"
    @assert city.r_prot > 0 "r_prot must be positive"
    @assert city.r_unprot > 0 "r_unprot must be positive"

    # f_runup should amplify, not attenuate
    @assert city.f_runup >= 1.0 "f_runup must be >= 1.0"

    return nothing
end

"""
    city_slope(city::CityParameters)

Compute city elevation gradient (H_city / D_city).
"""
city_slope(city::CityParameters) = city.H_city / city.D_city
