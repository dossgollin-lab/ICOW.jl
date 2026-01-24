# Pure numeric damage functions for the iCOW model
# Implements Equation 9 and zone-specific damage from _background/equations.md

using Random

# =============================================================================
# Pure numeric functions
# =============================================================================

"""
    base_zone_damage(z_low, z_high, value, h_surge, b_basement, H_bldg, f_damage)

Calculate base damage for a zone (before modifiers like resistance or dike factors).
Uses C++ damage formula with basement depth.
"""
function base_zone_damage(z_low, z_high, value, h_surge, b_basement, H_bldg, f_damage)
    T = typeof(value)

    # WashOver = surge height above zone bottom
    washOver = max(zero(T), h_surge - z_low)

    # Zone height
    zone_height = z_high - z_low

    # If no flooding or zone has no value, return 0
    if washOver <= zero(T) || value <= zero(T) || zone_height <= zero(T)
        return zero(T)
    end

    # C++ damage formula with basement
    if washOver < zone_height
        # Partial flooding: washOver * (washOver/2 + Basement) / (BH * zone_height)
        flood_fraction = washOver * (washOver / 2 + b_basement) / (H_bldg * zone_height)
    else
        # Full flooding: (Basement + zone_height/2) / BH
        flood_fraction = (b_basement + zone_height / 2) / H_bldg
    end

    # Equation 9: d_Z = Val_Z * flood_fraction * f_damage
    return value * flood_fraction * f_damage
end

"""
    zone_damage(zone::Zone, h_surge, b_basement, H_bldg, f_damage, P, f_intact, f_failed, dike_failed)

Calculate damage for a single zone based on zone type.
"""
function zone_damage(zone::Zone{T}, h_surge, b_basement, H_bldg, f_damage, P, f_intact, f_failed, dike_failed::Bool) where {T}
    # Zone 0 (withdrawn): no value remains
    if zone.zone_type == ZONE_WITHDRAWN
        return zero(T)
    end

    # Calculate base damage
    base_damage = base_zone_damage(
        zone.z_low, zone.z_high, zone.value, h_surge,
        b_basement, H_bldg, f_damage
    )

    if zone.zone_type == ZONE_RESISTANT
        # Zone 1: apply resistance factor (1-P)
        return base_damage * (one(T) - P)
    elseif zone.zone_type == ZONE_DIKE_PROTECTED
        # Zone 3: apply dike factor
        dike_factor = dike_failed ? f_failed : f_intact
        return base_damage * dike_factor
    else
        # Zones 2, 4: standard damage, no modifiers
        return base_damage
    end
end

"""
    event_damage(zones::CityZones, h_surge, b_basement, H_bldg, f_damage, P, f_intact, f_failed, d_thresh, f_thresh, gamma_thresh, dike_failed)

Calculate total damage for a single surge event (deterministic).
Includes threshold penalty. See _background/equations.md.
"""
function event_damage(zones::CityZones{T}, h_surge, b_basement, H_bldg, f_damage, P, f_intact, f_failed, d_thresh, f_thresh, gamma_thresh, dike_failed::Bool) where {T}
    # Sum damage across all zones
    total_damage = zero(T)
    for zone in zones
        total_damage += zone_damage(zone, h_surge, b_basement, H_bldg, f_damage, P, f_intact, f_failed, dike_failed)
    end

    # Apply threshold penalty if damage exceeds d_thresh
    if total_damage > d_thresh
        excess = total_damage - d_thresh
        penalty = (f_thresh * excess)^gamma_thresh
        total_damage += penalty
    end

    return total_damage
end

"""
    expected_damage_given_surge(h_raw, zones, H_seawall, f_runup, W, B, D, t_fail, p_min, b_basement, H_bldg, f_damage, P, f_intact, f_failed, d_thresh, f_thresh, gamma_thresh)

Calculate expected damage for a single surge height, integrating over dike failure.
Uses analytical expectation: E[damage|h] = p_fail*d_failed + (1-p_fail)*d_intact
"""
function expected_damage_given_surge(h_raw, zones::CityZones{T}, H_seawall, f_runup, W, B, D, t_fail, p_min, b_basement, H_bldg, f_damage, P, f_intact, f_failed, d_thresh, f_thresh, gamma_thresh) where {T}
    # Convert raw surge to effective surge
    h_eff = effective_surge(h_raw, H_seawall, f_runup)

    # Calculate surge height at dike (above dike base)
    dike_base = W + B
    h_at_dike = max(zero(T), h_eff - dike_base)

    # Get dike failure probability
    p_fail = dike_failure_probability(h_at_dike, D, t_fail, p_min)

    # Calculate damage for both dike states
    d_intact = event_damage(zones, h_eff, b_basement, H_bldg, f_damage, P, f_intact, f_failed, d_thresh, f_thresh, gamma_thresh, false)
    d_failed = event_damage(zones, h_eff, b_basement, H_bldg, f_damage, P, f_intact, f_failed, d_thresh, f_thresh, gamma_thresh, true)

    # Return analytical expectation
    return p_fail * d_failed + (one(T) - p_fail) * d_intact
end

# =============================================================================
# Convenience wrappers that take CityParameters and Levers
# =============================================================================

"""
    zone_damage(zone::Zone, h_surge, city::CityParameters, levers::Levers; dike_failed=false)

Calculate damage for a single zone. Wrapper for pure numeric function.
"""
function zone_damage(zone::Zone{T}, h_surge, city::CityParameters{T}, levers::Levers{T}; dike_failed::Bool=false) where {T}
    return zone_damage(
        zone, h_surge,
        city.b_basement, city.H_bldg, city.f_damage,
        levers.P, city.f_intact, city.f_failed,
        dike_failed
    )
end

"""
    event_damage(h_surge, city::CityParameters, levers::Levers; dike_failed=false)

Calculate total damage for a single surge event. Wrapper for pure numeric function.
"""
function event_damage(h_surge, city::CityParameters{T}, levers::Levers{T}; dike_failed::Bool=false) where {T}
    # Get city zones
    zones = city_zones(city, levers)

    return event_damage(
        zones, h_surge,
        city.b_basement, city.H_bldg, city.f_damage,
        levers.P, city.f_intact, city.f_failed,
        city.d_thresh, city.f_thresh, city.gamma_thresh,
        dike_failed
    )
end

"""
    event_damage_stochastic(h_surge, city::CityParameters, levers::Levers, rng::AbstractRNG)

Calculate damage with stochastic dike failure.
Uses dike_failure_probability and samples Bernoulli.
"""
function event_damage_stochastic(h_surge, city::CityParameters{T}, levers::Levers{T}, rng::AbstractRNG) where {T}
    # Calculate effective surge
    h_eff = effective_surge(h_surge, city)

    # Surge height at dike (above dike base)
    dike_base = levers.W + levers.B
    h_at_dike = max(zero(T), h_eff - dike_base)

    # Calculate dike failure probability
    p_fail = dike_failure_probability(h_at_dike, levers.D, city)

    # Sample dike failure
    dike_failed = rand(rng) < p_fail

    # Calculate damage with sampled dike state
    return event_damage(h_eff, city, levers; dike_failed=dike_failed)
end

"""
    expected_damage_given_surge(h_raw, city::CityParameters, levers::Levers)

Calculate expected damage for a single surge height. Wrapper for pure numeric function.
"""
function expected_damage_given_surge(h_raw, city::CityParameters{T}, levers::Levers{T}) where {T}
    # Get city zones
    zones = city_zones(city, levers)

    return expected_damage_given_surge(
        h_raw, zones,
        city.H_seawall, city.f_runup,
        levers.W, levers.B, levers.D,
        city.t_fail, city.p_min,
        city.b_basement, city.H_bldg, city.f_damage,
        levers.P, city.f_intact, city.f_failed,
        city.d_thresh, city.f_thresh, city.gamma_thresh
    )
end
