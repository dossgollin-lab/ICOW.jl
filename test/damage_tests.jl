using ICOW
using Test
using Random

@testset "Event Damage Calculations" begin
    city = CityParameters()

    @testset "Zero surge produces zero damage" begin
        levers = Levers(2.0, 3.0, 0.5, 4.0, 5.0)
        @test calculate_event_damage(0.0, city, levers) == 0.0
    end

    @testset "Surge below city produces zero damage" begin
        levers = Levers(5.0, 3.0, 0.5, 4.0, 2.0)
        # h_surge < W means no flooding of remaining city
        @test calculate_event_damage(2.0, city, levers) == 0.0
    end

    @testset "Damage monotonicity with surge height" begin
        levers = Levers(2.0, 3.0, 0.0, 4.0, 5.0)

        d1 = calculate_event_damage(3.0, city, levers)
        d2 = calculate_event_damage(6.0, city, levers)
        d3 = calculate_event_damage(10.0, city, levers)

        @test d1 < d2 < d3
    end

    @testset "Resistance reduces Zone 1 damage" begin
        # Same levers except P changes
        h_surge = 8.0

        # No resistance
        levers_no_resist = Levers(2.0, 3.0, 0.0, 4.0, 5.0)
        d_no_resist = calculate_event_damage(h_surge, city, levers_no_resist)

        # With resistance
        levers_with_resist = Levers(2.0, 3.0, 0.5, 4.0, 5.0)
        d_with_resist = calculate_event_damage(h_surge, city, levers_with_resist)

        @test d_with_resist < d_no_resist
    end

    @testset "Dike failure increases Zone 3 damage" begin
        levers = Levers(2.0, 3.0, 0.0, 4.0, 5.0)
        h_surge = 8.0  # Floods into Zone 3

        # Dike intact: uses f_intact (0.03)
        d_intact = calculate_event_damage(h_surge, city, levers; dike_failed=false)

        # Dike failed: uses f_failed (1.5)
        d_failed = calculate_event_damage(h_surge, city, levers; dike_failed=true)

        # f_failed > f_intact, so damage should be higher when dike fails
        @test d_failed > d_intact
    end

    @testset "Threshold penalty applies" begin
        # Create scenario with high damage to trigger threshold
        city_high_damage = CityParameters(d_thresh=1e6)  # Low threshold
        levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
        h_surge = 15.0  # High surge

        damage = calculate_event_damage(h_surge, city_high_damage, levers)

        # Damage should exceed threshold, triggering penalty
        # Total damage should be > base damage
        @test damage > city_high_damage.d_thresh
    end

    @testset "Stochastic damage samples dike failure" begin
        levers = Levers(2.0, 3.0, 0.0, 4.0, 5.0)
        # Zone 3 (dike protected) is at W+B to W+B+D = 7 to 11
        # For stochastic dike failure: t_fail*D < h_at_dike < D
        # h_at_dike = h_eff - (W+B) = h_eff - 7
        # Need: 3.8 < h_eff - 7 < 4, i.e., 10.8 < h_eff < 11
        # h_eff = h_raw * f_runup - H_seawall
        # h_raw = (h_eff + H_seawall) / f_runup = (10.9 + 1.75) / 1.1 ≈ 11.5
        h_raw = 11.5
        rng = MersenneTwister(42)

        # Run multiple samples to check variation
        damages = [calculate_event_damage_stochastic(h_raw, city, levers, rng) for _ in 1:100]

        # Should have some variation due to stochastic dike failure
        @test length(unique(damages)) > 1
    end

    @testset "Type stability" begin
        city32 = CityParameters{Float32}()
        levers32 = Levers(2.0f0, 3.0f0, 0.5f0, 4.0f0, 1.0f0)

        @test calculate_event_damage(5.0f0, city32, levers32) isa Float32

        rng = MersenneTwister(42)
        @test calculate_event_damage_stochastic(5.0f0, city32, levers32, rng) isa Float32
    end
end
