# Core types for the iCOW model

"""
    Levers{T<:Real}

Decision levers for the iCOW coastal flood model.

Five decision variables control the city's flood protection strategy:
- `W`: Withdrawal height (m) - absolute elevation below which city is relocated
- `R`: Resistance height (m) - height of flood-proofing above W (relative)
- `P`: Resistance percentage - fraction of buildings made resistant [0, 1)
- `D`: Dike height (m) - height of dike above its base (relative)
- `B`: Dike base height (m) - elevation of dike base above W (relative)

# Coordinate System
W is the only absolute lever (measured from seawall/sea level).
All other levers (R, B, D) are relative to W.
- Dike base is at absolute elevation: W + B
- Dike top is at absolute elevation: W + B + D

# Constraints (enforced in constructor)
- W >= 0, R >= 0, D >= 0, B >= 0 (non-negative)
- 0 <= P < 1.0 (strictly less than 1 to avoid division by zero in Equation 3)

City-dependent constraints are checked separately via `is_feasible(levers, city)`.

# Examples
```julia
levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)  # No protection
levers = Levers(5.0, 2.0, 0.5, 5.0, 2.0)  # Mixed strategy
levers = Levers{Float32}(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)  # Single precision
```
"""
struct Levers{T<:Real}
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

"""
    is_feasible(levers::Levers, city::CityParameters) -> Bool

Check if lever settings are feasible for the given city.
Returns `true` if all city-dependent constraints are satisfied.

# Constraints Checked
- W <= H_city (cannot withdraw above city peak)
- W + B + D <= H_city (dike cannot exceed city elevation)

# Examples
```julia
city = CityParameters()  # H_city = 17.0
is_feasible(Levers(5.0, 2.0, 0.5, 5.0, 2.0), city)  # true
is_feasible(Levers(18.0, 0.0, 0.0, 0.0, 0.0), city)  # false (W > H_city)
```
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

In the simulation engine, protection levels can only increase over time.
This function supports the idiom: `new_levers = max(target_levers, current_levers)`

# Examples
```julia
current = Levers(1.0, 2.0, 0.3, 4.0, 1.0)
target = Levers(2.0, 1.0, 0.5, 3.0, 2.0)
result = max(current, target)  # (2.0, 2.0, 0.5, 4.0, 2.0)
```
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
