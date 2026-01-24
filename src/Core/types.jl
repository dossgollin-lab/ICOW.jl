# Core types for the iCOW model
# Plain structs without SimOptDecisions dependencies

"""
    Levers{T<:Real}

Decision levers (W, R, P, D, B) for flood protection strategy.
W is absolute; R, P, D, B are relative to W. See _background/equations.md.
"""
struct Levers{T<:Real}
    W::T  # Withdrawal height (m) - absolute
    R::T  # Resistance height (m) - relative to W
    P::T  # Resistance percentage [0, 1)
    D::T  # Dike height (m) - relative to W+B
    B::T  # Dike base height (m) - relative to W

    function Levers{T}(W::T, R::T, P::T, D::T, B::T) where {T<:Real}
        # W >= 0; withdrawal cannot be negative
        @assert W >= zero(T) "W must be non-negative"

        # R >= 0; resistance height cannot be negative
        @assert R >= zero(T) "R must be non-negative"

        # 0 <= P < 1.0; resistance percentage must be a valid fraction
        # P = 1.0 causes division by zero in Equation 3 (term 1/(1-P))
        @assert P >= zero(T) "P must be non-negative"
        @assert P < one(T) "P must be strictly less than 1.0 (division by zero in Equation 3)"

        # D >= 0; dike height cannot be negative
        @assert D >= zero(T) "D must be non-negative"

        # B >= 0; dike base cannot be negative
        @assert B >= zero(T) "B must be non-negative"

        new{T}(W, R, P, D, B)
    end
end

# Outer constructor with explicit type parameter
Levers(W::T, R::T, P::T, D::T, B::T) where {T<:Real} = Levers{T}(W, R, P, D, B)

# Outer constructor with type promotion for mixed numeric types
function Levers(W, R, P, D, B)
    promoted = promote(W, R, P, D, B)
    T = eltype(promoted)
    Levers{T}(promoted...)
end

# Keyword argument constructor with defaults (all zeros)
function Levers(; W::Real=0.0, R::Real=0.0, P::Real=0.0, D::Real=0.0, B::Real=0.0)
    Levers(W, R, P, D, B)
end

"""
    Base.max(a::Levers{T}, b::Levers{T}) where {T}

Element-wise maximum of two Levers, for irreversibility enforcement.
"""
function Base.max(a::Levers{T}, b::Levers{T}) where {T}
    Levers{T}(
        max(a.W, b.W),
        max(a.R, b.R),
        max(a.P, b.P),
        max(a.D, b.D),
        max(a.B, b.B)
    )
end

# Display methods - show only non-zero levers
function Base.show(io::IO, l::Levers)
    parts = String[]
    l.W != 0 && push!(parts, "W=$(l.W)m")
    l.R != 0 && push!(parts, "R=$(l.R)m")
    l.P != 0 && push!(parts, "P=$(round(l.P*100, digits=1))%")
    l.D != 0 && push!(parts, "D=$(l.D)m")
    l.B != 0 && push!(parts, "B=$(l.B)m")
    if isempty(parts)
        print(io, "Levers(none)")
    else
        print(io, "Levers(", join(parts, ", "), ")")
    end
end

"""
    CityParameters{T<:Real}

Exogenous parameters for the iCOW coastal flood model.
See _background/equations.md for full parameter documentation.
"""
Base.@kwdef struct CityParameters{T<:Real}
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
    is_feasible(levers::Levers, city::CityParameters) -> Bool

Check if lever settings are feasible for the given city.
"""
function is_feasible(levers::Levers, city::CityParameters)
    # W <= H_city; cannot withdraw above city peak
    levers.W <= city.H_city || return false

    # W + B + D <= H_city; dike top cannot exceed city elevation
    levers.W + levers.B + levers.D <= city.H_city || return false

    return true
end

# Display methods
function Base.show(io::IO, city::CityParameters)
    print(io, "CityParameters(V=\$$(city.V_city/1e12)T, H=$(city.H_city)m)")
end

function Base.show(io::IO, ::MIME"text/plain", city::CityParameters{T}) where {T}
    println(io, "CityParameters{$T}")
    println(io, "  City value: \$$(city.V_city/1e12) trillion")
    println(io, "  Max elevation: $(city.H_city) m")
    println(io, "  Coastline: $(city.W_city/1000) km")
    print(io, "  Seawall height: $(city.H_seawall) m")
end
