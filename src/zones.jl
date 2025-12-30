# Zone-based city model for the iCOW model
# Implements zone partitioning from Figure 3 and docs/equations.md

"""
    AbstractZone{T<:Real}

Base type for city zones. Enables dispatch on zone-specific damage behavior.
"""
abstract type AbstractZone{T<:Real} end

"""
    WithdrawnZone{T<:Real}

Zone 0: Withdrawn area (0 to W). No value remains, no damage.
"""
struct WithdrawnZone{T<:Real} <: AbstractZone{T}
    z_low::T    # Lower boundary (absolute elevation)
    z_high::T   # Upper boundary (absolute elevation)
    value::T    # Economic value in this zone
end

"""
    ResistantZone{T<:Real}

Zone 1: Resistant area (W to W+min(R,B)). Damage reduced by (1-P).
"""
struct ResistantZone{T<:Real} <: AbstractZone{T}
    z_low::T
    z_high::T
    value::T
end

"""
    UnprotectedZone{T<:Real}

Zone 2: Unprotected gap (W+min(R,B) to W+B). Standard damage.
"""
struct UnprotectedZone{T<:Real} <: AbstractZone{T}
    z_low::T
    z_high::T
    value::T
end

"""
    DikeProtectedZone{T<:Real}

Zone 3: Dike-protected area (W+B to W+B+D). Uses f_intact or f_failed multiplier.
"""
struct DikeProtectedZone{T<:Real} <: AbstractZone{T}
    z_low::T
    z_high::T
    value::T
end

"""
    AboveDikeZone{T<:Real}

Zone 4: Above dike (W+B+D to H_city). Standard damage.
"""
struct AboveDikeZone{T<:Real} <: AbstractZone{T}
    z_low::T
    z_high::T
    value::T
end

"""
    CityZones{T<:Real}

Fixed-size container for exactly 5 city zones.
Uses heterogeneous Tuple for compile-time dispatch and zero allocations.
"""
struct CityZones{T<:Real}
    zones::Tuple{WithdrawnZone{T}, ResistantZone{T}, UnprotectedZone{T}, DikeProtectedZone{T}, AboveDikeZone{T}}

    function CityZones{T}(zones::Tuple{WithdrawnZone{T}, ResistantZone{T}, UnprotectedZone{T}, DikeProtectedZone{T}, AboveDikeZone{T}}) where {T<:Real}
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
CityZones(zones::Tuple{WithdrawnZone{T}, ResistantZone{T}, UnprotectedZone{T}, DikeProtectedZone{T}, AboveDikeZone{T}}) where {T<:Real} = CityZones{T}(zones)

# Indexing support
Base.getindex(cz::CityZones, i::Int) = cz.zones[i]
Base.length(::CityZones) = 5
Base.iterate(cz::CityZones, state=1) = state > 5 ? nothing : (cz.zones[state], state + 1)

"""
    calculate_city_zones(city::CityParameters, levers::Levers) -> CityZones

Partition city into 5 zones based on lever settings. See docs/equations.md.
Always returns exactly 5 zones; empty zones have width=0 and value=0.
"""
function calculate_city_zones(city::CityParameters{T}, levers::Levers{T}) where {T<:Real}
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
    # Val_Z0 = 0 (withdrawn)
    val_z0 = zero(T)

    # Val_Z1 = V_w * r_unprot * min(R, B) / (H_city - W)
    val_z1 = V_w * city.r_unprot * min(levers.R, levers.B) / remaining_height

    # Val_Z2 = V_w * r_unprot * max(0, B - R) / (H_city - W)
    val_z2 = V_w * city.r_unprot * max(zero(T), levers.B - levers.R) / remaining_height

    # Val_Z3 = V_w * r_prot * D / (H_city - W)
    val_z3 = V_w * city.r_prot * levers.D / remaining_height

    # Val_Z4 = V_w * (H_city - W - B - D) / (H_city - W)
    val_z4 = V_w * (remaining_height - levers.B - levers.D) / remaining_height

    # Create zones
    zone0 = WithdrawnZone{T}(z0_low, z0_high, val_z0)
    zone1 = ResistantZone{T}(z1_low, z1_high, val_z1)
    zone2 = UnprotectedZone{T}(z2_low, z2_high, val_z2)
    zone3 = DikeProtectedZone{T}(z3_low, z3_high, val_z3)
    zone4 = AboveDikeZone{T}(z4_low, z4_high, val_z4)

    return CityZones((zone0, zone1, zone2, zone3, zone4))
end
