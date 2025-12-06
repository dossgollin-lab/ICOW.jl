"""
    Levers

Represents the five decision levers for coastal defense strategies.

# Fields
- `withdraw_h::Float64`: W - Height below which city is relocated (m)
- `resist_h::Float64`: R - Height of flood-proofing (m)
- `resist_p::Float64`: P - Percentage of resistance (0.0 - 1.0)
- `dike_h::Float64`: D - Height of dike above base (m)
- `dike_base_h::Float64`: B - Elevation of dike base above seawall (m)

# Constraints
All levers are validated at construction time. Invalid configurations throw ArgumentError.

Physical constraints:
1. Dike top (B+D) cannot exceed city height
2. Withdrawal height (W) cannot exceed dike base (B)
3. Resistance percentage (P) must be in [0, 1]
4. All heights must be non-negative

# Examples
```julia
# Valid construction
levers = Levers(2.0, 3.0, 0.5, 5.0, 4.0)

# From vector (for optimization)
x = [2.0, 3.0, 0.5, 5.0, 4.0]
levers = Levers(x)

# Disable validation (use with caution)
levers = Levers(2.0, 3.0, 0.5, 5.0, 4.0; validate=false)
```
"""
struct Levers
    withdraw_h::Float64
    resist_h::Float64
    resist_p::Float64
    dike_h::Float64
    dike_base_h::Float64

    function Levers(W::Real, R::Real, P::Real, D::Real, B::Real;
                    city_max_height::Real=17.0,
                    validate::Bool=true)
        # Convert to Float64
        W, R, P, D, B = Float64.((W, R, P, D, B))

        # Validate if requested
        if validate
            # Constraint 1: Dike cannot exceed city height
            @assert B + D ≤ city_max_height "Dike top (B+D=$(B+D)) exceeds city max height ($city_max_height)"

            # Constraint 2: Withdrawal must be below dike base
            @assert W ≤ B "Withdrawal height ($W) cannot exceed dike base ($B)"

            # Constraint 3: Resistance percentage bounds
            @assert 0.0 ≤ P ≤ 1.0 "Resistance percentage ($P) must be in [0, 1]"

            # Constraint 4: All heights non-negative
            @assert all(≥(0), [W, R, D, B]) "All heights must be non-negative: W=$W, R=$R, D=$D, B=$B"
        end

        new(W, R, P, D, B)
    end
end

"""
    Levers(x::AbstractVector; kwargs...) -> Levers

Convenience constructor from vector (for optimization).

Converts 5-element vector [W, R, P, D, B] into Levers.
"""
Levers(x::AbstractVector; kwargs...) = Levers(x[1], x[2], x[3], x[4], x[5]; kwargs...)

"""
    Base.max(l1::Levers, l2::Levers) -> Levers

Element-wise maximum of two lever sets (for irreversibility enforcement).

Returns a new Levers struct where each field is the maximum of the corresponding fields.
This is used in the simulation engine to enforce that protection levels can only increase.

Validation is disabled for the result since both inputs are assumed valid.
"""
Base.max(l1::Levers, l2::Levers) = Levers(
    max(l1.withdraw_h, l2.withdraw_h),
    max(l1.resist_h, l2.resist_h),
    max(l1.resist_p, l2.resist_p),
    max(l1.dike_h, l2.dike_h),
    max(l1.dike_base_h, l2.dike_base_h);
    validate=false  # Already validated
)

"""
    is_feasible(levers::Levers, city::CityParameters) -> Bool

Check if a set of levers satisfies all physical constraints.

Returns false if any constraint is violated.

# Constraints checked:
1. Dike top (B+D) ≤ city max height
2. Withdrawal height (W) ≤ dike base (B)
3. Resistance percentage (P) ∈ [0, 1]
4. All heights ≥ 0

Note: These constraints should already be enforced by the Levers constructor,
but this function provides an additional check for debugging.
"""
function is_feasible(levers::Levers, city::CityParameters)::Bool
    (levers.dike_base_h + levers.dike_h ≤ city.city_max_height) &&
    (levers.withdraw_h ≤ levers.dike_base_h) &&
    (0.0 ≤ levers.resist_p ≤ 1.0) &&
    all(≥(0), [levers.withdraw_h, levers.resist_h, levers.dike_h, levers.dike_base_h])
end
