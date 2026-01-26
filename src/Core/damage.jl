# Pure numeric damage functions for the iCOW model
# Implements Equation 9 and zone-specific damage from _background/equations.md

"""
    base_zone_damage(z_low, z_high, value, h_surge, b_basement, H_bldg, f_damage) -> damage

Calculate base damage for a zone before modifiers (Equation 9). See _background/equations.md.
"""
function base_zone_damage(
    z_low::T, z_high::T, value::T, h_surge::T, b_basement::T, H_bldg::T, f_damage::T
) where {T<:AbstractFloat}
    wash_over = max(zero(T), h_surge - z_low)
    zone_height = z_high - z_low

    if wash_over <= zero(T) || value <= zero(T) || zone_height <= zero(T)
        return zero(T)
    end

    if wash_over < zone_height
        # Partial flooding
        flood_fraction = wash_over * (wash_over / 2 + b_basement) / (H_bldg * zone_height)
    else
        # Full flooding
        flood_fraction = (b_basement + zone_height / 2) / H_bldg
    end

    return value * flood_fraction * f_damage
end

"""
    zone_damage(zone_idx, z_low, z_high, value, h_surge, b_basement, H_bldg, f_damage, P, f_intact, f_failed, dike_failed) -> damage

Calculate damage for a single zone with zone-specific modifiers (Equation 9). See _background/equations.md.
"""
function zone_damage(
    zone_idx::Int,
    z_low::T,
    z_high::T,
    value::T,
    h_surge::T,
    b_basement::T,
    H_bldg::T,
    f_damage::T,
    P::T,
    f_intact::T,
    f_failed::T,
    dike_failed::Bool,
) where {T<:AbstractFloat}
    # Zone 0 (withdrawn): no damage
    if zone_idx == 0
        return zero(T)
    end

    base_dmg = base_zone_damage(z_low, z_high, value, h_surge, b_basement, H_bldg, f_damage)

    if zone_idx == 1
        # Zone 1 (resistant): apply resistance factor (1-P)
        return base_dmg * (one(T) - P)
    elseif zone_idx == 3
        # Zone 3 (dike-protected): apply dike factor
        dike_factor = dike_failed ? f_failed : f_intact
        return base_dmg * dike_factor
    else
        # Zones 2, 4: standard damage
        return base_dmg
    end
end

"""
    total_event_damage(bounds, values, h_surge, ..., dike_failed) -> damage

Calculate total damage for a single surge event across all zones. See _background/equations.md.
"""
function total_event_damage(
    bounds::NTuple{10,T},
    values::NTuple{5,T},
    h_surge::T,
    b_basement::T,
    H_bldg::T,
    f_damage::T,
    P::T,
    f_intact::T,
    f_failed::T,
    d_thresh::T,
    f_thresh::T,
    gamma_thresh::T,
    dike_failed::Bool,
) where {T<:AbstractFloat}
    total_dmg = zero(T)

    # Sum damage across all 5 zones
    for i in 0:4
        z_low = bounds[2 * i + 1]
        z_high = bounds[2 * i + 2]
        value = values[i + 1]
        total_dmg += zone_damage(
            i,
            z_low,
            z_high,
            value,
            h_surge,
            b_basement,
            H_bldg,
            f_damage,
            P,
            f_intact,
            f_failed,
            dike_failed,
        )
    end

    # Apply threshold penalty
    if total_dmg > d_thresh
        excess = total_dmg - d_thresh
        penalty = (f_thresh * excess)^gamma_thresh
        total_dmg += penalty
    end

    return total_dmg
end

"""
    expected_damage_given_surge(h_raw, bounds, values, H_seawall, f_runup, W, B, D, t_fail, p_min, b_basement, H_bldg, f_damage, P, f_intact, f_failed, d_thresh, f_thresh, gamma_thresh)

Calculate expected damage for a single surge height, integrating over dike failure.
Returns: p_fail * d_failed + (1-p_fail) * d_intact
"""
function expected_damage_given_surge(
    h_raw::T,
    bounds::NTuple{10,T},
    values::NTuple{5,T},
    H_seawall::T,
    f_runup::T,
    W::T,
    B::T,
    D::T,
    t_fail::T,
    p_min::T,
    b_basement::T,
    H_bldg::T,
    f_damage::T,
    P::T,
    f_intact::T,
    f_failed::T,
    d_thresh::T,
    f_thresh::T,
    gamma_thresh::T,
) where {T<:AbstractFloat}
    h_eff = effective_surge(h_raw, H_seawall, f_runup)
    dike_base = W + B
    h_at_dike = max(zero(T), h_eff - dike_base)
    p_fail = dike_failure_probability(h_at_dike, D, t_fail, p_min)

    d_intact = total_event_damage(
        bounds,
        values,
        h_eff,
        b_basement,
        H_bldg,
        f_damage,
        P,
        f_intact,
        f_failed,
        d_thresh,
        f_thresh,
        gamma_thresh,
        false,
    )
    d_failed = total_event_damage(
        bounds,
        values,
        h_eff,
        b_basement,
        H_bldg,
        f_damage,
        P,
        f_intact,
        f_failed,
        d_thresh,
        f_thresh,
        gamma_thresh,
        true,
    )

    return p_fail * d_failed + (one(T) - p_fail) * d_intact
end
