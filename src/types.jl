# Core types for the iCOW model
# Types inherit from SimOptDecisions abstract types

"""
    Levers{T<:Real} <: SimOptDecisions.AbstractAction

Decision levers (W, R, P, D, B) for flood protection strategy.
W is absolute; R, P, D, B are relative to W. See docs/equations.md.
"""
struct Levers{T<:Real} <: SimOptDecisions.AbstractAction
    W::T  # Withdrawal height (m) - absolute
    R::T  # Resistance height (m) - relative to W
    P::T  # Resistance percentage [0, 1)
    D::T  # Dike height (m) - relative to W+B
    B::T  # Dike base height (m) - relative to W

    # Inner constructor with basic validation
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
