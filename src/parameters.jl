# Parameters for the iCOW (Island City on a Wedge) model
# All defaults from docs/equations.md (C++ values where paper differs)

"""
    CityParameters{T<:Real}

Exogenous parameters for the iCOW coastal flood model.

Contains 27 parameters organized by category:
- Geometry (6): City dimensions and seawall
- Dike (4): Dike construction parameters
- Zones (2): Value ratios for protected/unprotected zones
- Withdrawal (2): Relocation cost factors
- Resistance (5): Flood-proofing cost factors
- Damage (6): Damage calculation factors
- Threshold (3): Catastrophic damage threshold parameters

All monetary values are in raw dollars (not scaled).
Heights are in meters.

# Examples
```julia
city = CityParameters()  # Default NYC-like parameters
city = CityParameters{Float32}()  # Single precision
city = CityParameters(V_city=2.0e12, H_city=20.0)  # Custom values
```
"""
struct CityParameters{T<:Real}
    # Geometry (6)
    V_city::T       # Initial city value ($)
    H_bldg::T       # Building height (m)
    H_city::T       # City max elevation (m)
    D_city::T       # City depth from seawall to peak (m)
    W_city::T       # City coastline length (m)
    H_seawall::T    # Seawall height (m)

    # Dike (4)
    D_startup::T    # Startup height for fixed costs (m)
    w_d::T          # Dike top width (m)
    s_dike::T       # Dike side slope (horizontal/vertical)
    c_d::T          # Dike cost per volume ($/m^3)

    # Zones (2)
    r_prot::T       # Protected zone value ratio
    r_unprot::T     # Unprotected zone value ratio

    # Withdrawal (2)
    f_w::T          # Withdrawal cost factor
    f_l::T          # Loss fraction (leaves vs relocates)

    # Resistance (5)
    f_adj::T        # Adjustment factor (hidden in C++ code)
    f_lin::T        # Linear cost factor
    f_exp::T        # Exponential cost factor
    t_exp::T        # Exponential threshold
    b_basement::T   # Basement depth (m)

    # Damage (6)
    f_damage::T     # Fraction of value lost per flood
    f_intact::T     # Damage factor when dike holds
    f_failed::T     # Damage factor when dike fails
    t_fail::T       # Surge/height ratio for failure onset
    p_min::T        # Minimum dike failure probability
    f_runup::T      # Wave runup amplification factor

    # Threshold (3)
    d_thresh::T     # Damage threshold for catastrophic effects ($)
    f_thresh::T     # Threshold fraction multiplier
    gamma_thresh::T # Threshold exponent
end

# Outer constructor with keyword arguments and defaults
function CityParameters{T}(;
    # Geometry
    V_city::Real = 1.5e12,
    H_bldg::Real = 30.0,
    H_city::Real = 17.0,
    D_city::Real = 2000.0,
    W_city::Real = 43000.0,
    H_seawall::Real = 1.75,
    # Dike
    D_startup::Real = 2.0,
    w_d::Real = 3.0,
    s_dike::Real = 0.5,
    c_d::Real = 10.0,
    # Zones
    r_prot::Real = 1.1,
    r_unprot::Real = 0.95,
    # Withdrawal
    f_w::Real = 1.0,
    f_l::Real = 0.01,
    # Resistance
    f_adj::Real = 1.25,
    f_lin::Real = 0.35,
    f_exp::Real = 0.115,
    t_exp::Real = 0.4,
    b_basement::Real = 3.0,
    # Damage
    f_damage::Real = 0.39,
    f_intact::Real = 0.03,
    f_failed::Real = 1.5,
    t_fail::Real = 0.95,
    p_min::Real = 0.05,
    f_runup::Real = 1.1,
    # Threshold (d_thresh defaults to V_city/375 if nothing)
    d_thresh::Union{Real,Nothing} = nothing,
    f_thresh::Real = 1.0,
    gamma_thresh::Real = 1.01
) where {T<:Real}
    # Compute d_thresh default with proper type promotion
    actual_d_thresh = isnothing(d_thresh) ? V_city / T(375) : T(d_thresh)

    CityParameters{T}(
        T(V_city), T(H_bldg), T(H_city), T(D_city), T(W_city), T(H_seawall),
        T(D_startup), T(w_d), T(s_dike), T(c_d),
        T(r_prot), T(r_unprot),
        T(f_w), T(f_l),
        T(f_adj), T(f_lin), T(f_exp), T(t_exp), T(b_basement),
        T(f_damage), T(f_intact), T(f_failed), T(t_fail), T(p_min), T(f_runup),
        actual_d_thresh, T(f_thresh), T(gamma_thresh)
    )
end

# Convenience constructor defaulting to Float64
CityParameters(; kwargs...) = CityParameters{Float64}(; kwargs...)

"""
    validate_parameters(city::CityParameters)

Validate physical bounds on city parameters.
Throws `AssertionError` if any constraint is violated.

# Constraints checked
- Positive: V_city, H_bldg, H_city, D_city, W_city, s_dike
- Non-negative: H_seawall, D_startup, w_d, c_d, b_basement, d_thresh
- Fractions [0,1]: f_l, f_damage, t_fail, p_min, t_exp
- Positive multipliers: f_w, f_adj, r_prot, r_unprot
- f_runup >= 1.0 (amplification factor)
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

Compute the city's elevation gradient (H_city / D_city).

Note: Uses the correct formula from the paper, NOT the buggy C++ implementation
which incorrectly uses CityLength/CityWidth.
"""
city_slope(city::CityParameters) = city.H_city / city.D_city
