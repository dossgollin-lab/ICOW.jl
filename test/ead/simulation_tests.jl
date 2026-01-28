using ICOW
using ICOW.EAD
using SimOptDecisions
using Random
using Distributions
using Test

@testset "SimOptDecisions Integration" begin
    @testset "Types subtype abstracts" begin
        @test EADConfig <: SimOptDecisions.AbstractConfig
        @test EADScenario <: SimOptDecisions.AbstractScenario
        @test EADState <: SimOptDecisions.AbstractState
        @test StaticPolicy <: SimOptDecisions.AbstractPolicy
        @test EADOutcome <: SimOptDecisions.AbstractOutcome
    end

    @testset "Simulation runs with quadrature" begin
        config = EADConfig(n_years=5)
        scenario = EADScenario(
            surge_loc=3.0, surge_scale=1.0, surge_shape=0.0, discount_rate=0.0,
            mean_sea_level=zeros(5),
        )
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)

        rng = MersenneTwister(42)
        outcome = simulate(config, scenario, policy, rng)

        @test outcome isa EADOutcome
        @test SimOptDecisions.value(outcome.investment) > 0.0
        @test SimOptDecisions.value(outcome.expected_damage) >= 0.0
    end

    @testset "Simulation runs with Monte Carlo" begin
        config = EADConfig(n_years=5, integrator=MonteCarloIntegrator(n_samples=100))
        scenario = EADScenario(
            surge_loc=3.0, surge_scale=1.0, surge_shape=0.0, discount_rate=0.0,
            mean_sea_level=zeros(5),
        )
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)

        rng = MersenneTwister(42)
        outcome = simulate(config, scenario, policy, rng)

        @test outcome isa EADOutcome
        @test SimOptDecisions.value(outcome.investment) > 0.0
        @test SimOptDecisions.value(outcome.expected_damage) >= 0.0
    end

    @testset "Zero policy produces zero investment" begin
        config = EADConfig(n_years=2)
        scenario = EADScenario(
            surge_loc=3.0, surge_scale=1.0, surge_shape=0.0, discount_rate=0.0,
            mean_sea_level=zeros(2),
        )
        policy = StaticPolicy(a_frac=0.0, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)

        rng = MersenneTwister(42)
        outcome = simulate(config, scenario, policy, rng)

        @test SimOptDecisions.value(outcome.investment) == 0.0
    end

    @testset "Quadrature is deterministic" begin
        config = EADConfig(n_years=5)
        scenario = EADScenario(
            surge_loc=3.0, surge_scale=1.0, surge_shape=0.0, discount_rate=0.03,
            mean_sea_level=zeros(5),
        )
        policy = StaticPolicy(a_frac=0.5, w_frac=0.1, b_frac=0.3, r_frac=0.2, P=0.5)

        # Quadrature should give identical results regardless of RNG
        outcome1 = simulate(config, scenario, policy, MersenneTwister(123))
        outcome2 = simulate(config, scenario, policy, MersenneTwister(456))

        @test SimOptDecisions.value(outcome1.investment) ==
            SimOptDecisions.value(outcome2.investment)
        @test SimOptDecisions.value(outcome1.expected_damage) ==
            SimOptDecisions.value(outcome2.expected_damage)
    end

    @testset "Monte Carlo varies with RNG but converges" begin
        config = EADConfig(n_years=3, integrator=MonteCarloIntegrator(n_samples=100))
        scenario = EADScenario(
            surge_loc=5.0, surge_scale=1.0, surge_shape=0.0, discount_rate=0.0,
            mean_sea_level=zeros(3),
        )
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        # Different seeds produce different MC results
        outcome1 = simulate(config, scenario, policy, MersenneTwister(1))
        outcome2 = simulate(config, scenario, policy, MersenneTwister(2))
        @test SimOptDecisions.value(outcome1.expected_damage) !=
            SimOptDecisions.value(outcome2.expected_damage)

        # Same seed produces same results
        outcome3 = simulate(config, scenario, policy, MersenneTwister(1))
        @test SimOptDecisions.value(outcome1.expected_damage) ==
            SimOptDecisions.value(outcome3.expected_damage)
    end

    @testset "Quadrature and Monte Carlo agree approximately" begin
        config_quad = EADConfig(n_years=3)
        config_mc = EADConfig(n_years=3, integrator=MonteCarloIntegrator(n_samples=10000))
        scenario = EADScenario(
            surge_loc=4.0, surge_scale=1.0, surge_shape=0.0, discount_rate=0.0,
            mean_sea_level=zeros(3),
        )
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        outcome_quad = simulate(config_quad, scenario, policy, MersenneTwister(42))
        outcome_mc = simulate(config_mc, scenario, policy, MersenneTwister(42))

        # MC should be within 5% of quadrature with enough samples
        quad_damage = SimOptDecisions.value(outcome_quad.expected_damage)
        mc_damage = SimOptDecisions.value(outcome_mc.expected_damage)
        @test isapprox(quad_damage, mc_damage, rtol=0.05)
    end

    @testset "Discounting applied correctly" begin
        config = EADConfig(n_years=3)
        scenario_no_discount = EADScenario(
            surge_loc=3.0, surge_scale=1.0, surge_shape=0.0, discount_rate=0.0,
            mean_sea_level=zeros(3),
        )
        scenario_with_discount = EADScenario(
            surge_loc=3.0, surge_scale=1.0, surge_shape=0.0, discount_rate=0.1,
            mean_sea_level=zeros(3),
        )
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        outcome_no = simulate(config, scenario_no_discount, policy, MersenneTwister(42))
        outcome_yes = simulate(config, scenario_with_discount, policy, MersenneTwister(42))

        # With positive discount rate, NPV should be lower (future costs worth less)
        @test total_cost(outcome_yes) < total_cost(outcome_no)
    end

    @testset "Near-deterministic surge matches tight-scale GEV" begin
        config = EADConfig(n_years=3)
        # Very small scale approximates a point mass at surge_loc
        scenario = EADScenario(
            surge_loc=5.0, surge_scale=0.001, surge_shape=0.0, discount_rate=0.0,
            mean_sea_level=zeros(3),
        )
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        config_mc = EADConfig(n_years=3, integrator=MonteCarloIntegrator(n_samples=100))
        outcome_quad = simulate(config, scenario, policy, MersenneTwister(42))
        outcome_mc = simulate(config_mc, scenario, policy, MersenneTwister(42))

        # With near-zero scale, both methods should give very similar results
        @test isapprox(
            SimOptDecisions.value(outcome_quad.expected_damage),
            SimOptDecisions.value(outcome_mc.expected_damage),
            rtol=0.01,
        )
    end

    @testset "Zero surge produces minimal damage" begin
        config = EADConfig(n_years=3)
        # Very low surge location with tiny scale
        scenario = EADScenario(
            surge_loc=-5.0, surge_scale=0.01, surge_shape=0.0, discount_rate=0.0,
            mean_sea_level=zeros(3),
        )
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        outcome = simulate(config, scenario, policy, MersenneTwister(42))
        @test SimOptDecisions.value(outcome.expected_damage) < 1.0  # effectively zero
    end

    @testset "Infeasible policy returns infinite costs" begin
        config = EADConfig(n_years=2)
        scenario = EADScenario(
            surge_loc=1.0, surge_scale=0.001, surge_shape=0.0, discount_rate=0.0,
            mean_sea_level=zeros(2),
        )
        # a_frac=1, w_frac=1 produces W = H_city, which is infeasible (strict inequality required)
        policy = StaticPolicy(a_frac=1.0, w_frac=1.0, b_frac=0.0, r_frac=0.0, P=0.0)

        outcome = simulate(config, scenario, policy, MersenneTwister(42))

        @test SimOptDecisions.value(outcome.investment) == Inf
        @test SimOptDecisions.value(outcome.expected_damage) == Inf
    end
end
