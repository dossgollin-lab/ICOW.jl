using ICOW

function main()
    city = CityParameters{Float64}()
    levers = Levers(0.0, 0.0, 0.0, 3.0, 0.0)
    h_eff = 0.45

    println("Testing zone damage calculation:")
    println("Effective surge: ", h_eff, " m")
    println("Dike top: ", levers.W + levers.B + levers.D, " m")
    println()

    # Get city zones
    city_zones = calculate_city_zones(city, levers)
    zones = city_zones.zones

    println("City zones:")
    for (i, zone) in enumerate(zones)
        println("  Zone $(i-1): elevation ", zone.z_low, " to ", zone.z_high,
                ", value \$", zone.value/1e6, "M")
    end
    println()

    # Calculate damage for each zone
    println("Zone damages (dike intact):")
    total_damage = 0.0
    for (i, zone) in enumerate(zones)
        d = calculate_zone_damage(zone, h_eff, city, levers; dike_failed=false)
        println("  Zone $(i-1): \$", d/1e6, "M")
        total_damage += d
    end
    println("Total: \$", total_damage/1e6, "M")
    println()

    # Also test with dike failed
    println("Zone damages (dike FAILED):")
    total_damage_failed = 0.0
    for (i, zone) in enumerate(zones)
        d = calculate_zone_damage(zone, h_eff, city, levers; dike_failed=true)
        println("  Zone $(i-1): \$", d/1e6, "M")
        total_damage_failed += d
    end
    println("Total: \$", total_damage_failed/1e6, "M")
end

main()
