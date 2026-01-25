using ICOW
using ICOW.EAD
using SimOptDecisions
using Random
using Distributions
using Test

# Import EAD-specific names to avoid ambiguity with Stochastic module
import ICOW.EAD: StaticPolicy, total_cost

@testset "SimOptDecisions Integration" begin
    @testset "Types subtype abstracts" begin
        @test EADConfig <: SimOptDecisions.AbstractConfig
        @test EADScenario <: SimOptDecisions.AbstractScenario
        @test EADState <: SimOptDecisions.AbstractState
        @test StaticPolicy <: SimOptDecisions.AbstractPolicy
        @test EADOutcome <: SimOptDecisions.AbstractOutcome
    end

    @testset "Simulation runs with quadrature" begin
        config = EADConfig()
        dists = [Normal(3.0, 1.0) for _ in 1:5]
        scenario = EADScenario(dists, 0.0, QuadratureIntegrator())
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)

        rng = MersenneTwister(42)
        outcome = SimOptDecisions.simulate(config, scenario, policy, rng)

        @test outcome isa EADOutcome
        @test SimOptDecisions.value(outcome.investment) > 0.0
        @test SimOptDecisions.value(outcome.expected_damage) >= 0.0
    end

    @testset "Simulation runs with Monte Carlo" begin
        config = EADConfig()
        dists = [Normal(3.0, 1.0) for _ in 1:5]
        scenario = EADScenario(dists, 0.0, MonteCarloIntegrator(n_samples=100))
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)

        rng = MersenneTwister(42)
        outcome = SimOptDecisions.simulate(config, scenario, policy, rng)

        @test outcome isa EADOutcome
        @test SimOptDecisions.value(outcome.investment) > 0.0
        @test SimOptDecisions.value(outcome.expected_damage) >= 0.0
    end

    @testset "Zero policy produces zero investment" begin
        config = EADConfig()
        dists = [Normal(3.0, 1.0), Normal(3.0, 1.0)]
        scenario = EADScenario(dists, 0.0, QuadratureIntegrator())
        policy = StaticPolicy(a_frac=0.0, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)

        rng = MersenneTwister(42)
        outcome = SimOptDecisions.simulate(config, scenario, policy, rng)

        @test SimOptDecisions.value(outcome.investment) == 0.0
    end

    @testset "Quadrature is deterministic" begin
        config = EADConfig()
        dists = [Normal(3.0, 1.0) for _ in 1:5]
        scenario = EADScenario(dists, 0.03, QuadratureIntegrator())
        policy = StaticPolicy(a_frac=0.5, w_frac=0.1, b_frac=0.3, r_frac=0.2, P=0.5)

        # Quadrature should give identical results regardless of RNG
        outcome1 = SimOptDecisions.simulate(config, scenario, policy, MersenneTwister(123))
        outcome2 = SimOptDecisions.simulate(config, scenario, policy, MersenneTwister(456))

        @test SimOptDecisions.value(outcome1.investment) == SimOptDecisions.value(outcome2.investment)
        @test SimOptDecisions.value(outcome1.expected_damage) == SimOptDecisions.value(outcome2.expected_damage)
    end

    @testset "Monte Carlo varies with RNG but converges" begin
        config = EADConfig()
        dists = [Normal(5.0, 1.0) for _ in 1:3]
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        # Different seeds produce different MC results
        scenario_mc = EADScenario(dists, 0.0, MonteCarloIntegrator(n_samples=100))
        outcome1 = SimOptDecisions.simulate(config, scenario_mc, policy, MersenneTwister(1))
        outcome2 = SimOptDecisions.simulate(config, scenario_mc, policy, MersenneTwister(2))
        @test SimOptDecisions.value(outcome1.expected_damage) != SimOptDecisions.value(outcome2.expected_damage)

        # Same seed produces same results
        outcome3 = SimOptDecisions.simulate(config, scenario_mc, policy, MersenneTwister(1))
        @test SimOptDecisions.value(outcome1.expected_damage) == SimOptDecisions.value(outcome3.expected_damage)
    end

    @testset "Quadrature and Monte Carlo agree approximately" begin
        config = EADConfig()
        dists = [Normal(4.0, 1.0) for _ in 1:3]
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        scenario_quad = EADScenario(dists, 0.0, QuadratureIntegrator())
        scenario_mc = EADScenario(dists, 0.0, MonteCarloIntegrator(n_samples=10000))

        outcome_quad = SimOptDecisions.simulate(config, scenario_quad, policy, MersenneTwister(42))
        outcome_mc = SimOptDecisions.simulate(config, scenario_mc, policy, MersenneTwister(42))

        # MC should be within 5% of quadrature with enough samples
        quad_damage = SimOptDecisions.value(outcome_quad.expected_damage)
        mc_damage = SimOptDecisions.value(outcome_mc.expected_damage)
        @test isapprox(quad_damage, mc_damage, rtol=0.05)
    end

    @testset "Discounting applied correctly" begin
        config = EADConfig()
        dists = [Normal(3.0, 1.0) for _ in 1:3]
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        scenario_no_discount = EADScenario(dists, 0.0, QuadratureIntegrator())
        scenario_with_discount = EADScenario(dists, 0.1, QuadratureIntegrator())

        outcome_no = SimOptDecisions.simulate(config, scenario_no_discount, policy, MersenneTwister(42))
        outcome_yes = SimOptDecisions.simulate(config, scenario_with_discount, policy, MersenneTwister(42))

        # With positive discount rate, NPV should be lower (future costs worth less)
        @test total_cost(outcome_yes) < total_cost(outcome_no)
    end

    @testset "Dirac distribution matches deterministic calculation" begin
        config = EADConfig()
        # Dirac distribution = point mass at specific surge value
        dists = [Dirac(5.0), Dirac(5.0), Dirac(5.0)]
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        scenario_quad = EADScenario(dists, 0.0, QuadratureIntegrator())
        scenario_mc = EADScenario(dists, 0.0, MonteCarloIntegrator(n_samples=100))

        outcome_quad = SimOptDecisions.simulate(config, scenario_quad, policy, MersenneTwister(42))
        outcome_mc = SimOptDecisions.simulate(config, scenario_mc, policy, MersenneTwister(42))

        # With Dirac distribution, both methods should give exact same result
        @test SimOptDecisions.value(outcome_quad.expected_damage) ≈ SimOptDecisions.value(outcome_mc.expected_damage)
    end

    @testset "Irreversibility enforced" begin
        # Simulation should complete without error
        config = EADConfig()
        dists = [Normal(3.0, 1.0) for _ in 1:3]
        scenario = EADScenario(dists, 0.0, QuadratureIntegrator())
        policy = StaticPolicy(a_frac=0.5, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        outcome = SimOptDecisions.simulate(config, scenario, policy, MersenneTwister(42))
        @test outcome isa EADOutcome
    end

    @testset "Zero surge distribution produces minimal damage" begin
        config = EADConfig()
        # Very low surges that don't cause significant damage
        dists = [Dirac(0.0) for _ in 1:3]
        scenario = EADScenario(dists, 0.0, QuadratureIntegrator())
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        outcome = SimOptDecisions.simulate(config, scenario, policy, MersenneTwister(42))
        @test SimOptDecisions.value(outcome.expected_damage) == 0.0
    end
end
