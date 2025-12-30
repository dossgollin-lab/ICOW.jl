using ICOW
using Test

@testset "Zone Structure" begin
    city = CityParameters()

    @testset "No protection (all zeros)" begin
        levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
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
        levers = Levers(5.0, 3.0, 0.0, 4.0, 5.0)
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
        levers = Levers(2.0, 6.0, 0.0, 3.0, 5.0)
        zones = calculate_city_zones(city, levers)

        # Zone 2 should have zero width and zero value when R >= B
        @test zones[3].z_low == zones[3].z_high
        @test zones[3].value == 0.0
    end

    @testset "Zone values use correct ratios" begin
        levers = Levers(3.0, 2.0, 0.0, 4.0, 6.0)
        zones = calculate_city_zones(city, levers)

        V_w = calculate_value_after_withdrawal(city, levers.W)
        remaining_height = city.H_city - levers.W

        # Verify individual zone values use correct formulas
        # Zone 1: r_unprot * min(R,B) / remaining_height
        expected_z1 = V_w * city.r_unprot * min(levers.R, levers.B) / remaining_height
        @test zones[2].value ≈ expected_z1

        # Zone 3: r_prot * D / remaining_height
        expected_z3 = V_w * city.r_prot * levers.D / remaining_height
        @test zones[4].value ≈ expected_z3

        # Total value should be close to V_w (within ~10% due to value ratios)
        total_value = sum(zone.value for zone in zones)
        @test total_value / V_w ≈ 1.0 atol=0.2
    end

    @testset "Empty zones have zero value" begin
        levers = Levers(0.0, 5.0, 0.0, 10.0, 5.0)
        zones = calculate_city_zones(city, levers)

        # Zone 0: withdrawn zone always has zero value
        @test zones[1].value == 0.0

        # Zone 2: R >= B, should have zero value
        @test zones[3].value == 0.0
    end

    @testset "Type stability" begin
        city32 = CityParameters{Float32}()
        levers32 = Levers(2.0f0, 3.0f0, 0.0f0, 4.0f0, 1.0f0)
        zones32 = calculate_city_zones(city32, levers32)

        @test zones32[1] isa WithdrawnZone{Float32}
        @test zones32[2] isa ResistantZone{Float32}
        @test zones32[3] isa UnprotectedZone{Float32}
        @test zones32[4] isa DikeProtectedZone{Float32}
        @test zones32[5] isa AboveDikeZone{Float32}
    end
end
