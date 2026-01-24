# Pure numeric zone functions for the iCOW model
# Implements zone partitioning from Figure 3 and _background/equations.md

"""
    zone_boundaries(H_city, W, R, B, D)

Calculate zone boundary elevations.
Returns tuple: (z0_low, z0_high, z1_low, z1_high, z2_low, z2_high, z3_low, z3_high, z4_low, z4_high)
"""
function zone_boundaries(H_city::T, W::T, R::T, B::T, D::T) where {T<:AbstractFloat}
    z0_low = zero(T)
    z0_high = W

    z1_low = W
    z1_high = W + min(R, B)

    z2_low = z1_high
    z2_high = W + B

    z3_low = z2_high
    z3_high = W + B + D

    z4_low = z3_high
    z4_high = H_city

    return (z0_low, z0_high, z1_low, z1_high, z2_low, z2_high, z3_low, z3_high, z4_low, z4_high)
end

"""
    zone_values(V_w, H_city, W, R, B, D, r_prot, r_unprot)

Calculate zone economic values.
Returns tuple of 5 values: (val_z0, val_z1, val_z2, val_z3, val_z4)
V_w is value after withdrawal.
"""
function zone_values(
    V_w::T, H_city::T, W::T, R::T, B::T, D::T, r_prot::T, r_unprot::T
) where {T<:AbstractFloat}
    remaining_height = H_city - W

    val_z0 = zero(T)  # Withdrawn
    val_z1 = V_w * r_unprot * min(R, B) / remaining_height
    val_z2 = V_w * r_unprot * max(zero(T), B - R) / remaining_height
    val_z3 = V_w * r_prot * D / remaining_height
    val_z4 = V_w * (remaining_height - B - D) / remaining_height

    return (val_z0, val_z1, val_z2, val_z3, val_z4)
end
