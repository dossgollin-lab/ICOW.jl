# Core types for the iCOW model
# Plain structs without SimOptDecisions dependencies

"""
    FloodDefenses{T<:Real}

Flood protection decisions (W, R, P, D, B).
W is absolute elevation; R, D, B are heights relative to W; P is a fraction.
See _background/equations.md.
"""
struct FloodDefenses{T<:Real}
    W::T  # Withdrawal height (m) - absolute
    R::T  # Resistance height (m) - relative to W
    P::T  # Resistance percentage [0, 1)
    D::T  # Dike height (m) - relative to W+B
    B::T  # Dike base height (m) - relative to W

    function FloodDefenses{T}(W::T, R::T, P::T, D::T, B::T) where {T<:Real}
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
FloodDefenses(W::T, R::T, P::T, D::T, B::T) where {T<:Real} = FloodDefenses{T}(W, R, P, D, B)

# Outer constructor with type promotion for mixed numeric types
function FloodDefenses(W, R, P, D, B)
    promoted = promote(W, R, P, D, B)
    T = eltype(promoted)
    FloodDefenses{T}(promoted...)
end

# Keyword argument constructor with defaults (all zeros)
function FloodDefenses(; W::Real=0.0, R::Real=0.0, P::Real=0.0, D::Real=0.0, B::Real=0.0)
    FloodDefenses(W, R, P, D, B)
end

"""
    Base.max(a::FloodDefenses{T}, b::FloodDefenses{T}) where {T}

Element-wise maximum of two FloodDefenses, for irreversibility enforcement.
"""
function Base.max(a::FloodDefenses{T}, b::FloodDefenses{T}) where {T}
    FloodDefenses{T}(
        max(a.W, b.W),
        max(a.R, b.R),
        max(a.P, b.P),
        max(a.D, b.D),
        max(a.B, b.B)
    )
end

# Display methods - show only non-zero levers
function Base.show(io::IO, l::FloodDefenses)
    parts = String[]
    l.W != 0 && push!(parts, "W=$(l.W)m")
    l.R != 0 && push!(parts, "R=$(l.R)m")
    l.P != 0 && push!(parts, "P=$(round(l.P*100, digits=1))%")
    l.D != 0 && push!(parts, "D=$(l.D)m")
    l.B != 0 && push!(parts, "B=$(l.B)m")
    if isempty(parts)
        print(io, "FloodDefenses(none)")
    else
        print(io, "FloodDefenses(", join(parts, ", "), ")")
    end
end
