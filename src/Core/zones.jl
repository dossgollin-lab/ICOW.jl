# Pure numeric zone functions for the iCOW model
# Implements zone partitioning from Figure 3 and _background/equations.md

# Zone type enum for type safety
@enum ZoneType begin
    ZONE_WITHDRAWN = 0
    ZONE_RESISTANT = 1
    ZONE_UNPROTECTED = 2
    ZONE_DIKE_PROTECTED = 3
    ZONE_ABOVE_DIKE = 4
end

"""
    Zone{T<:Real}

City zone with type, boundaries, and economic value.
Zone types: ZONE_WITHDRAWN, ZONE_RESISTANT, ZONE_UNPROTECTED, ZONE_DIKE_PROTECTED, ZONE_ABOVE_DIKE.
"""
struct Zone{T<:Real}
    zone_type::ZoneType  # See ZoneType enum
    z_low::T             # Lower boundary (absolute elevation)
    z_high::T            # Upper boundary (absolute elevation)
    value::T             # Economic value in this zone
end

"""
    CityZones{T<:Real}

Fixed-size container for exactly 5 city zones.
"""
struct CityZones{T<:Real}
    zones::NTuple{5, Zone{T}}

    function CityZones{T}(zones::NTuple{5, Zone{T}}) where {T<:Real}
        # Validate zones are ordered
        for i in 1:4
            @assert zones[i].z_high <= zones[i+1].z_low "Zones must be ordered and non-overlapping"
        end

        # Validate non-negative values
        for zone in zones
            @assert zone.value >= zero(T) "Zone values must be non-negative"
        end

        new{T}(zones)
    end
end

# Constructor from tuple
CityZones(zones::NTuple{5, Zone{T}}) where {T<:Real} = CityZones{T}(zones)

# Indexing support
Base.getindex(cz::CityZones, i::Int) = cz.zones[i]
Base.length(::CityZones) = 5
Base.iterate(cz::CityZones, state=1) = state > 5 ? nothing : (cz.zones[state], state + 1)

# =============================================================================
# Pure numeric functions
# =============================================================================

"""
    zone_boundaries(H_city, W, R, B, D)

Calculate zone boundary elevations. Returns tuple of (z0_low, z0_high, z1_low, z1_high, ...).
"""
function zone_boundaries(H_city, W, R, B, D)
    T = typeof(W)

    # Zone boundaries (absolute elevations)
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

Calculate zone economic values. Returns tuple of 5 values.
V_w is value after withdrawal (from costs.jl).
"""
function zone_values(V_w, H_city, W, R, B, D, r_prot, r_unprot)
    T = typeof(V_w)
    remaining_height = H_city - W

    # Zone values (from equations.md)
    # When R >= B, Zone 1 width = min(R,B) = B and Zone 2 width = max(0, B-R) = 0
    val_z0 = zero(T)  # Withdrawn
    val_z1 = V_w * r_unprot * min(R, B) / remaining_height
    val_z2 = V_w * r_unprot * max(zero(T), B - R) / remaining_height  # Zero when R >= B
    val_z3 = V_w * r_prot * D / remaining_height
    val_z4 = V_w * (remaining_height - B - D) / remaining_height

    return (val_z0, val_z1, val_z2, val_z3, val_z4)
end

"""
    city_zones(V_w, H_city, W, R, B, D, r_prot, r_unprot)

Partition city into 5 zones. Pure numeric function.
Returns CityZones struct with 5 zones.
"""
function city_zones(V_w, H_city, W, R, B, D, r_prot, r_unprot)
    T = typeof(V_w)

    # Get boundaries and values
    bounds = zone_boundaries(H_city, W, R, B, D)
    values = zone_values(V_w, H_city, W, R, B, D, r_prot, r_unprot)

    # Create zones
    zones = (
        Zone{T}(ZONE_WITHDRAWN, bounds[1], bounds[2], values[1]),
        Zone{T}(ZONE_RESISTANT, bounds[3], bounds[4], values[2]),
        Zone{T}(ZONE_UNPROTECTED, bounds[5], bounds[6], values[3]),
        Zone{T}(ZONE_DIKE_PROTECTED, bounds[7], bounds[8], values[4]),
        Zone{T}(ZONE_ABOVE_DIKE, bounds[9], bounds[10], values[5])
    )

    return CityZones(zones)
end

# =============================================================================
# Convenience wrapper that takes CityParameters and Levers
# =============================================================================

"""
    city_zones(city::CityParameters, levers::Levers) -> CityZones

Partition city into 5 zones based on lever settings. Wrapper for pure numeric function.
"""
function city_zones(city::CityParameters{T}, levers::Levers{T}) where {T<:Real}
    # Get value after withdrawal (Equation 2)
    V_w = value_after_withdrawal(city, levers.W)

    return city_zones(
        V_w, city.H_city,
        levers.W, levers.R, levers.B, levers.D,
        city.r_prot, city.r_unprot
    )
end
