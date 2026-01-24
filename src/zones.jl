# Zone-based city model for the iCOW model
# Implements zone partitioning from Figure 3 and docs/equations.md

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

"""
    calculate_city_zones(city::CityParameters, levers::Levers) -> CityZones

Partition city into 5 zones based on lever settings. See docs/equations.md.
Always returns exactly 5 zones; empty zones have width=0 and value=0.
"""
function calculate_city_zones(city::Core.CityParameters{T}, levers::Core.Levers{T}) where {T<:Real}
    # Get value after withdrawal (Equation 2)
    V_w = calculate_value_after_withdrawal(city, levers.W)
    remaining_height = city.H_city - levers.W

    # Zone boundaries (absolute elevations)
    z0_low = zero(T)
    z0_high = levers.W

    z1_low = levers.W
    z1_high = levers.W + min(levers.R, levers.B)

    z2_low = z1_high
    z2_high = levers.W + levers.B

    z3_low = z2_high
    z3_high = levers.W + levers.B + levers.D

    z4_low = z3_high
    z4_high = city.H_city

    # Zone values (from equations.md)
    # When R >= B, Zone 1 width = min(R,B) = B and Zone 2 width = max(0, B-R) = 0
    val_z0 = zero(T)  # Withdrawn
    val_z1 = V_w * city.r_unprot * min(levers.R, levers.B) / remaining_height
    val_z2 = V_w * city.r_unprot * max(zero(T), levers.B - levers.R) / remaining_height  # Zero when R >= B
    val_z3 = V_w * city.r_prot * levers.D / remaining_height
    val_z4 = V_w * (remaining_height - levers.B - levers.D) / remaining_height

    # Create zones
    zones = (
        Zone{T}(ZONE_WITHDRAWN, z0_low, z0_high, val_z0),
        Zone{T}(ZONE_RESISTANT, z1_low, z1_high, val_z1),
        Zone{T}(ZONE_UNPROTECTED, z2_low, z2_high, val_z2),
        Zone{T}(ZONE_DIKE_PROTECTED, z3_low, z3_high, val_z3),
        Zone{T}(ZONE_ABOVE_DIKE, z4_low, z4_high, val_z4)
    )

    return CityZones(zones)
end
