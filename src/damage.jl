# Event damage calculations for the iCOW model
# Implements Equation 9 and zone-specific damage from docs/equations.md

"""
    calculate_zone_damage(zone::WithdrawnZone, h_surge, city, levers; dike_failed=false)

Zone 0 damage: always zero (no value remains).
"""
function calculate_zone_damage(zone::WithdrawnZone{T}, h_surge::Real, city::CityParameters{T}, levers::Levers{T}; dike_failed::Bool=false) where {T<:Real}
    return zero(T)
end

"""
    calculate_zone_damage(zone::ResistantZone, h_surge, city, levers; dike_failed=false)

Zone 1 damage: standard formula multiplied by (1-P) for resistance.
"""
function calculate_zone_damage(zone::ResistantZone{T}, h_surge::Real, city::CityParameters{T}, levers::Levers{T}; dike_failed::Bool=false) where {T<:Real}
    # Calculate base damage using C++ formula
    base_damage = _calculate_base_zone_damage(zone, h_surge, city)

    # Apply resistance factor (1-P)
    return base_damage * (one(T) - levers.P)
end

"""
    calculate_zone_damage(zone::UnprotectedZone, h_surge, city, levers; dike_failed=false)

Zone 2 damage: standard formula, no modifiers.
"""
function calculate_zone_damage(zone::UnprotectedZone{T}, h_surge::Real, city::CityParameters{T}, levers::Levers{T}; dike_failed::Bool=false) where {T<:Real}
    return _calculate_base_zone_damage(zone, h_surge, city)
end

"""
    calculate_zone_damage(zone::DikeProtectedZone, h_surge, city, levers; dike_failed=false)

Zone 3 damage: standard formula multiplied by f_intact or f_failed.
"""
function calculate_zone_damage(zone::DikeProtectedZone{T}, h_surge::Real, city::CityParameters{T}, levers::Levers{T}; dike_failed::Bool=false) where {T<:Real}
    # Calculate base damage using C++ formula
    base_damage = _calculate_base_zone_damage(zone, h_surge, city)

    # Apply dike factor
    dike_factor = dike_failed ? city.f_failed : city.f_intact
    return base_damage * dike_factor
end

"""
    calculate_zone_damage(zone::AboveDikeZone, h_surge, city, levers; dike_failed=false)

Zone 4 damage: standard formula, no modifiers.
"""
function calculate_zone_damage(zone::AboveDikeZone{T}, h_surge::Real, city::CityParameters{T}, levers::Levers{T}; dike_failed::Bool=false) where {T<:Real}
    return _calculate_base_zone_damage(zone, h_surge, city)
end

"""
    _calculate_base_zone_damage(zone::AbstractZone, h_surge, city)

Internal: C++ damage formula with basement depth.
Matches C++ functions CalculateDamageResiliantUnprotectedZone1, etc.
"""
function _calculate_base_zone_damage(zone::AbstractZone{T}, h_surge::Real, city::CityParameters{T}) where {T<:Real}
    # WashOver = surge height above zone bottom
    washOver = max(zero(T), h_surge - zone.z_low)

    # Zone height
    zone_height = zone.z_high - zone.z_low

    # If no flooding or zone has no value, return 0
    if washOver <= zero(T) || zone.value <= zero(T) || zone_height <= zero(T)
        return zero(T)
    end

    # C++ damage formula with basement
    Basement = city.b_basement
    BH = city.H_bldg

    if washOver < zone_height
        # Partial flooding: washOver * (washOver/2 + Basement) / (BH * zone_height)
        flood_fraction = washOver * (washOver / 2 + Basement) / (BH * zone_height)
    else
        # Full flooding: (Basement + zone_height/2) / BH
        flood_fraction = (Basement + zone_height / 2) / BH
    end

    # Equation 9: d_Z = Val_Z * flood_fraction * f_damage
    return zone.value * flood_fraction * city.f_damage
end

"""
    calculate_event_damage(h_surge, city::CityParameters, levers::Levers; dike_failed=false)

Calculate total damage for a single surge event (deterministic).
Includes threshold penalty. See docs/equations.md.
"""
function calculate_event_damage(h_surge::Real, city::CityParameters{T}, levers::Levers{T}; dike_failed::Bool=false) where {T<:Real}
    # Get city zones
    zones = calculate_city_zones(city, levers)

    # Sum damage across all zones
    total_damage = zero(T)
    for zone in zones
        total_damage += calculate_zone_damage(zone, h_surge, city, levers; dike_failed=dike_failed)
    end

    # Apply threshold penalty if damage exceeds d_thresh
    if total_damage > city.d_thresh
        excess = total_damage - city.d_thresh
        penalty = (city.f_thresh * excess)^city.gamma_thresh
        total_damage += penalty
    end

    return total_damage
end

"""
    calculate_event_damage_stochastic(h_surge, city::CityParameters, levers::Levers, rng::AbstractRNG)

Calculate damage with stochastic dike failure.
Uses calculate_dike_failure_probability and samples Bernoulli.
"""
function calculate_event_damage_stochastic(h_surge::Real, city::CityParameters{T}, levers::Levers{T}, rng::AbstractRNG) where {T<:Real}
    # Calculate effective surge (if not already effective)
    h_eff = calculate_effective_surge(h_surge, city)

    # Surge height at dike (above dike base)
    dike_base = levers.W + levers.B
    h_at_dike = max(zero(T), h_eff - dike_base)

    # Calculate dike failure probability
    p_fail = calculate_dike_failure_probability(h_at_dike, levers.D, city)

    # Sample dike failure
    dike_failed = rand(rng) < p_fail

    # Calculate damage with sampled dike state
    return calculate_event_damage(h_eff, city, levers; dike_failed=dike_failed)
end

"""
    calculate_expected_damage_given_surge(h_raw, city, levers) -> expected_damage

Calculate expected damage for a single surge height, integrating over dike failure.
Uses analytical expectation. See docs/equations.md.
"""
function calculate_expected_damage_given_surge(h_raw::Real, city::CityParameters{T}, levers::Levers{T}) where {T<:Real}
    # Convert raw surge to effective surge
    h_eff = calculate_effective_surge(h_raw, city)

    # Calculate surge height at dike (above dike base)
    dike_base = levers.W + levers.B
    h_at_dike = max(zero(T), h_eff - dike_base)

    # Get dike failure probability
    p_fail = calculate_dike_failure_probability(h_at_dike, levers.D, city)

    # Calculate damage for both dike states
    d_intact = calculate_event_damage(h_eff, city, levers; dike_failed=false)
    d_failed = calculate_event_damage(h_eff, city, levers; dike_failed=true)

    # Return analytical expectation: E[damage|h] = p_fail*d_failed + (1-p_fail)*d_intact
    return p_fail * d_failed + (one(T) - p_fail) * d_intact
end

"""
    calculate_expected_damage_mc(city, levers, dist; n_samples=1000, rng=default_rng())

Monte Carlo integration over surge distribution (Equation 9 integrated).
See docs/equations.md.
"""
function calculate_expected_damage_mc(city::CityParameters{T}, levers::Levers{T}, dist::Distribution; n_samples::Int=1000, rng::AbstractRNG=Random.default_rng()) where {T<:Real}
    # Sample surges from distribution
    surges = rand(rng, dist, n_samples)

    # Calculate expected damage for each surge sample
    damages = T[calculate_expected_damage_given_surge(h, city, levers) for h in surges]

    # Return mean damage
    return mean(damages)
end

"""
    calculate_expected_damage_quad(city, levers, dist; rtol=1e-6)

Numerical quadrature integration over surge distribution. See docs/equations.md.

Special handling: Dirac distributions are evaluated directly (deterministic case).
Uses infinite bounds to capture heavy tails in GEV distributions.
"""
function calculate_expected_damage_quad(city::CityParameters{T}, levers::Levers{T}, dist::Distribution; rtol::Real=1e-6) where {T<:Real}
    # Special case: Dirac distribution (deterministic)
    # Dirac has pdf=0 everywhere except at single point (infinite), so quadrature fails
    # Instead, directly evaluate at the deterministic value
    if dist isa Dirac
        return calculate_expected_damage_given_surge(dist.value, city, levers)
    end

    # Define integrand: pdf(h) * E[damage|h]
    integrand(h) = pdf(dist, h) * calculate_expected_damage_given_surge(h, city, levers)

    # Integrate using adaptive quadrature with infinite bounds
    # This correctly handles heavy-tailed distributions (e.g., GEV with ξ > 0)
    result, err = quadgk(integrand, -Inf, Inf; rtol=rtol)

    return result
end

"""
    calculate_expected_damage(city, levers, forcing, year; method=:quad, kwargs...)

Calculate expected annual damage for a given year. Dispatches to MC or quadrature.
See docs/equations.md.
"""
function calculate_expected_damage(city::CityParameters, levers::Levers, forcing::DistributionalForcing, year::Int; method::Symbol=:quad, kwargs...)
    # Extract distribution for this year
    dist = get_distribution(forcing, year)

    # Dispatch based on method
    if method == :mc
        return calculate_expected_damage_mc(city, levers, dist; kwargs...)
    elseif method == :quad
        return calculate_expected_damage_quad(city, levers, dist; kwargs...)
    else
        throw(ArgumentError("method must be :mc or :quad, got $method"))
    end
end
