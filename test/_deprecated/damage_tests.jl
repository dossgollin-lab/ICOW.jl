using ICOW
using Test
using Random
using Distributions
using Statistics

@testset "Event Damage Calculations" begin
    city = CityParameters()

    @testset "Zero surge produces zero damage" begin
        levers = FloodDefenses(2.0, 3.0, 0.5, 4.0, 5.0)
        @test calculate_event_damage(0.0, city, levers) == 0.0
    end

    @testset "Surge below city produces zero damage" begin
        levers = FloodDefenses(5.0, 3.0, 0.5, 4.0, 2.0)
        # h_surge < W means no flooding of remaining city
        @test calculate_event_damage(2.0, city, levers) == 0.0
    end

    @testset "Damage monotonicity with surge height" begin
        levers = FloodDefenses(2.0, 3.0, 0.0, 4.0, 5.0)

        d1 = calculate_event_damage(3.0, city, levers)
        d2 = calculate_event_damage(6.0, city, levers)
        d3 = calculate_event_damage(10.0, city, levers)

        @test d1 < d2 < d3
    end

    @testset "Resistance reduces Zone 1 damage" begin
        # Same levers except P changes
        h_surge = 8.0

        # No resistance
        levers_no_resist = FloodDefenses(2.0, 3.0, 0.0, 4.0, 5.0)
        d_no_resist = calculate_event_damage(h_surge, city, levers_no_resist)

        # With resistance
        levers_with_resist = FloodDefenses(2.0, 3.0, 0.5, 4.0, 5.0)
        d_with_resist = calculate_event_damage(h_surge, city, levers_with_resist)

        @test d_with_resist < d_no_resist
    end

    @testset "Dike failure increases Zone 3 damage" begin
        levers = FloodDefenses(2.0, 3.0, 0.0, 4.0, 5.0)
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
        levers = FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0)
        h_surge = 15.0  # High surge

        damage = calculate_event_damage(h_surge, city_high_damage, levers)

        # Damage should exceed threshold, triggering penalty
        # Total damage should be > base damage
        @test damage > city_high_damage.d_thresh
    end

    @testset "Stochastic damage samples dike failure" begin
        levers = FloodDefenses(2.0, 3.0, 0.0, 4.0, 5.0)
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
        levers32 = FloodDefenses(2.0f0, 3.0f0, 0.5f0, 4.0f0, 1.0f0)

        @test calculate_event_damage(5.0f0, city32, levers32) isa Float32

        rng = MersenneTwister(42)
        @test calculate_event_damage_stochastic(5.0f0, city32, levers32, rng) isa Float32
    end
end

@testset "Expected Annual Damage" begin
    city = CityParameters()
    levers = FloodDefenses(2.0, 3.0, 0.5, 4.0, 5.0)

    @testset "Zero surge distribution" begin
        # Zero surge → zero damage
        dist_zero = Dirac(0.0)
        @test calculate_expected_damage_mc(city, levers, dist_zero) == 0.0
        @test calculate_expected_damage_quad(city, levers, dist_zero) ≈ 0.0 atol=1e-10
    end

    @testset "Dirac distribution matches deterministic" begin
        # Dirac distribution represents deterministic case (no surge uncertainty)
        # Using Dirac ensures type stability - always returns a Distribution
        h = 5.0
        dist = Dirac(h)
        expected = calculate_expected_damage_given_surge(h, city, levers)

        # Monte Carlo should match (all samples have same value)
        ead_mc = calculate_expected_damage_mc(city, levers, dist; n_samples=100)
        @test ead_mc ≈ expected rtol=1e-6

        # Quadrature has special handling for Dirac (evaluates directly)
        ead_quad = calculate_expected_damage_quad(city, levers, dist)
        @test ead_quad ≈ expected rtol=1e-10
    end

    @testset "Monte Carlo convergence" begin
        # Higher n_samples → lower variance across trials
        dist = Normal(5.0, 2.0)
        rng = MersenneTwister(42)

        # Run multiple trials with different sample counts
        trials_100 = [calculate_expected_damage_mc(city, levers, dist; n_samples=100, rng=MersenneTwister(i)) for i in 1:20]
        trials_1000 = [calculate_expected_damage_mc(city, levers, dist; n_samples=1000, rng=MersenneTwister(i)) for i in 1:20]

        # Standard deviation should decrease with more samples
        @test std(trials_1000) < std(trials_100)
    end

    @testset "MC vs Quadrature agreement" begin
        # Methods should agree within tolerance for smooth distributions
        dist = Normal(5.0, 2.0)
        rng = MersenneTwister(42)

        ead_mc = calculate_expected_damage_mc(city, levers, dist; n_samples=10000, rng=rng)
        ead_quad = calculate_expected_damage_quad(city, levers, dist)

        # 5% relative tolerance
        @test ead_mc ≈ ead_quad rtol=0.05
    end

    @testset "Monotonicity with distribution mean" begin
        # Higher mean surge → higher EAD
        dist_low = Normal(3.0, 1.0)
        dist_high = Normal(6.0, 1.0)

        ead_low = calculate_expected_damage_mc(city, levers, dist_low; n_samples=1000)
        ead_high = calculate_expected_damage_mc(city, levers, dist_high; n_samples=1000)

        @test ead_high > ead_low
    end

    @testset "Type stability" begin
        # Float32 calculations
        city32 = CityParameters{Float32}()
        levers32 = FloodDefenses(2.0f0, 3.0f0, 0.5f0, 4.0f0, 1.0f0)
        dist32 = Normal{Float32}(5.0f0, 2.0f0)

        @test calculate_expected_damage_given_surge(5.0f0, city32, levers32) isa Float32
        @test calculate_expected_damage_mc(city32, levers32, dist32; n_samples=100) isa Float32
        # Note: QuadGK may not preserve Float32, returns Float64 - this is acceptable
        @test calculate_expected_damage_quad(city32, levers32, dist32) isa Real
    end

    @testset "Dispatcher interface" begin
        # Main interface works with DistributionalForcing
        dist1 = Normal(5.0, 2.0)
        dist2 = Normal(6.0, 2.5)
        forcing = DistributionalForcing([dist1, dist2], 2020)

        # Test MC method
        ead_mc = calculate_expected_damage(city, levers, forcing, 1; method=:mc, n_samples=1000)
        @test ead_mc > 0.0

        # Test quad method
        ead_quad = calculate_expected_damage(city, levers, forcing, 1; method=:quad)
        @test ead_quad > 0.0

        # Should agree within tolerance
        @test ead_mc ≈ ead_quad rtol=0.1

        # Year 2 has higher mean, should have higher EAD
        ead_year2 = calculate_expected_damage(city, levers, forcing, 2; method=:mc, n_samples=1000)
        @test ead_year2 > ead_mc

        # Invalid method should error
        @test_throws ArgumentError calculate_expected_damage(city, levers, forcing, 1; method=:invalid)
    end

    @testset "Expected damage is bounded by intact/failed extremes" begin
        # Expected damage should lie between min(d_intact, d_failed) and max(d_intact, d_failed)
        h_raw = 8.0
        city_test = CityParameters()
        levers_test = FloodDefenses(2.0, 3.0, 0.0, 4.0, 5.0)

        expected = calculate_expected_damage_given_surge(h_raw, city_test, levers_test)
        h_eff = calculate_effective_surge(h_raw, city_test)
        d_intact = calculate_event_damage(h_eff, city_test, levers_test; dike_failed=false)
        d_failed = calculate_event_damage(h_eff, city_test, levers_test; dike_failed=true)

        @test d_intact <= expected <= d_failed
    end
end
