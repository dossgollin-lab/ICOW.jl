using ICOW
using Test

@testset "Zone Structure" begin
    city = CityParameters()

    @testset "No protection (all zeros)" begin
        levers = FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0)
        zones = calculate_city_zones(city, levers)

        # Zone 0: withdrawn (no value)
        @test zones[1].z_low == 0.0
        @test zones[1].z_high == 0.0
        @test zones[1].value == 0.0

        # Zone 4: entire city above dike
        @test zones[5].z_low == 0.0
        @test zones[5].z_high == city.H_city
        @test zones[5].value ≈ city.V_city
    end

    @testset "Typical protection (W=5, R=3, B=5, D=4)" begin
        levers = FloodDefenses(5.0, 3.0, 0.0, 4.0, 5.0)
        zones = calculate_city_zones(city, levers)

        # Zone boundaries
        @test zones[1].z_low == 0.0
        @test zones[1].z_high == 5.0

        @test zones[2].z_low == 5.0
        @test zones[2].z_high == 8.0  # W + min(R,B) = 5 + 3

        @test zones[3].z_low == 8.0
        @test zones[3].z_high == 10.0  # W + B = 5 + 5

        @test zones[4].z_low == 10.0
        @test zones[4].z_high == 14.0  # W + B + D = 5 + 5 + 4

        @test zones[5].z_low == 14.0
        @test zones[5].z_high == city.H_city
    end

    @testset "Zone 2 empty when R >= B" begin
        levers = FloodDefenses(2.0, 6.0, 0.0, 3.0, 5.0)
        zones = calculate_city_zones(city, levers)

        # Zone 2 should have zero width and zero value when R >= B
        @test zones[3].z_low == zones[3].z_high
        @test zones[3].value == 0.0
    end

    @testset "Zone values use correct ratios" begin
        levers = FloodDefenses(3.0, 2.0, 0.0, 4.0, 6.0)
        zones = calculate_city_zones(city, levers)

        V_w = calculate_value_after_withdrawal(city, levers.W)
        remaining_height = city.H_city - levers.W

        # Zone 1: r_unprot * min(R,B) / remaining_height
        expected_z1 = V_w * city.r_unprot * min(levers.R, levers.B) / remaining_height
        @test zones[2].value ≈ expected_z1

        # Zone 3: r_prot * D / remaining_height
        expected_z3 = V_w * city.r_prot * levers.D / remaining_height
        @test zones[4].value ≈ expected_z3

        # Total value differs from V_w due to r_unprot (0.95) and r_prot (1.1) multipliers
        # Expected ratio is approximately 1.0071 for these levers, not exactly 1.0
        total_value = sum(zone.value for zone in zones)
        @test total_value / V_w ≈ 1.0 rtol=0.02
    end

    @testset "Type stability" begin
        city32 = CityParameters{Float32}()
        levers32 = FloodDefenses(2.0f0, 3.0f0, 0.0f0, 4.0f0, 1.0f0)
        zones32 = calculate_city_zones(city32, levers32)

        # All zones should be Zone{Float32}
        expected_types = [ZONE_WITHDRAWN, ZONE_RESISTANT, ZONE_UNPROTECTED, ZONE_DIKE_PROTECTED, ZONE_ABOVE_DIKE]
        for (i, zone) in enumerate(zones32)
            @test zone isa Zone{Float32}
            @test zone.zone_type == expected_types[i]
        end
    end
end
