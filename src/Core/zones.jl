# Pure numeric zone functions for the iCOW model
# Implements zone partitioning from Figure 3 and _background/equations.md

"""
    zone_boundaries(H_city, W, R, B, D) -> NTuple{10}

Calculate zone boundary elevations (Figure 3). See _background/equations.md.
When there is no dike (B=0 and D=0), Zone 1 extends to W+R (resistance-only strategy).
"""
function zone_boundaries(H_city::T, W::T, R::T, B::T, D::T) where {T<:AbstractFloat}
    z0_low = zero(T)
    z0_high = W

    z1_low = W
    # When no dike (B=0 and D=0), Zone 1 extends to full resistance height R
    # Otherwise, Zone 1 is capped at the dike base (min(R, B))
    if B == zero(T) && D == zero(T)
        z1_high = W + R
    else
        z1_high = W + min(R, B)
    end

    z2_low = z1_high
    # When no dike (B=0 and D=0), zones 2-3 collapse to same point as zone 1 top
    if B == zero(T) && D == zero(T)
        z2_high = z1_high
    else
        z2_high = W + B
    end

    z3_low = z2_high
    if B == zero(T) && D == zero(T)
        z3_high = z1_high
    else
        z3_high = W + B + D
    end

    z4_low = z3_high
    z4_high = H_city

    return (
        z0_low, z0_high, z1_low, z1_high, z2_low, z2_high, z3_low, z3_high, z4_low, z4_high
    )
end

"""
    zone_values(V_w, H_city, W, R, B, D, r_prot, r_unprot) -> NTuple{5}

Calculate zone economic values (Zone Values section). See _background/equations.md.
When there is no dike (B=0 and D=0), Zone 1 uses full resistance height R.
"""
function zone_values(
    V_w::T, H_city::T, W::T, R::T, B::T, D::T, r_prot::T, r_unprot::T
) where {T<:AbstractFloat}
    @assert W < H_city "W must be strictly less than H_city to avoid division by zero"
    remaining_height = H_city - W

    val_z0 = zero(T)  # Withdrawn

    # When no dike (B=0 and D=0), Zone 1 uses full R and Zone 4 is remainder after R
    # No r_unprot multiplier in this case (matches C++ case 8 behavior)
    if B == zero(T) && D == zero(T)
        val_z1 = V_w * R / remaining_height
        val_z2 = zero(T)
        val_z3 = zero(T)
        val_z4 = V_w * (remaining_height - R) / remaining_height
    else
        val_z1 = V_w * r_unprot * min(R, B) / remaining_height
        val_z2 = V_w * r_unprot * max(zero(T), B - R) / remaining_height
        val_z3 = V_w * r_prot * D / remaining_height
        val_z4 = V_w * (remaining_height - B - D) / remaining_height
    end

    return (val_z0, val_z1, val_z2, val_z3, val_z4)
end
