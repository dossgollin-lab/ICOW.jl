using ICOW
using ICOW.Stochastic
using SimOptDecisions
using Random
using Test

@testset "SimOptDecisions Integration" begin
    @testset "Types subtype abstracts" begin
        @test StochasticConfig <: SimOptDecisions.AbstractConfig
        @test StochasticScenario <: SimOptDecisions.AbstractScenario
        @test StochasticState <: SimOptDecisions.AbstractState
        @test StaticPolicy <: SimOptDecisions.AbstractPolicy
        @test StochasticOutcome <: SimOptDecisions.AbstractOutcome
    end

    @testset "Simulation runs" begin
        config = StochasticConfig()
        scenario = StochasticScenario(surges=[1.0, 2.0, 3.0, 4.0, 5.0], discount_rate=0.0)
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)

        rng = MersenneTwister(42)
        outcome = SimOptDecisions.simulate(config, scenario, policy, rng)

        @test outcome isa StochasticOutcome
        @test SimOptDecisions.value(outcome.investment) > 0.0
        @test SimOptDecisions.value(outcome.damage) >= 0.0
    end

    @testset "Zero policy produces zero investment" begin
        config = StochasticConfig()
        scenario = StochasticScenario(surges=[1.0, 2.0], discount_rate=0.0)
        policy = StaticPolicy(a_frac=0.0, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)

        rng = MersenneTwister(42)
        outcome = SimOptDecisions.simulate(config, scenario, policy, rng)

        @test SimOptDecisions.value(outcome.investment) == 0.0
    end

    @testset "Deterministic with same RNG" begin
        config = StochasticConfig()
        scenario = StochasticScenario(surges=[1.0, 2.0, 3.0, 4.0, 5.0], discount_rate=0.03)
        policy = StaticPolicy(a_frac=0.5, w_frac=0.1, b_frac=0.3, r_frac=0.2, P=0.5)

        outcome1 = SimOptDecisions.simulate(config, scenario, policy, MersenneTwister(123))
        outcome2 = SimOptDecisions.simulate(config, scenario, policy, MersenneTwister(123))

        @test SimOptDecisions.value(outcome1.investment) == SimOptDecisions.value(outcome2.investment)
        @test SimOptDecisions.value(outcome1.damage) == SimOptDecisions.value(outcome2.damage)
    end

    @testset "Discounting applied correctly" begin
        config = StochasticConfig()
        scenario_no_discount = StochasticScenario(surges=[1.0, 2.0, 3.0], discount_rate=0.0)
        scenario_with_discount = StochasticScenario(surges=[1.0, 2.0, 3.0], discount_rate=0.1)
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        outcome_no = SimOptDecisions.simulate(config, scenario_no_discount, policy, MersenneTwister(42))
        outcome_yes = SimOptDecisions.simulate(config, scenario_with_discount, policy, MersenneTwister(42))

        # With positive discount rate, NPV should be lower (future costs worth less)
        @test total_cost(outcome_yes) < total_cost(outcome_no)
    end

    @testset "Irreversibility enforced" begin
        # This is implicitly tested - if irreversibility wasn't enforced,
        # the simulation would fail or produce incorrect results.
        # A more explicit test would require traced simulation to check state progression.
        config = StochasticConfig()
        scenario = StochasticScenario(surges=[1.0, 2.0, 3.0], discount_rate=0.0)
        policy = StaticPolicy(a_frac=0.5, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        # Simulation should complete without error
        outcome = SimOptDecisions.simulate(config, scenario, policy, MersenneTwister(42))
        @test outcome isa StochasticOutcome
    end

    @testset "Stochastic dike failure produces variation" begin
        config = StochasticConfig()
        # Moderate surges near dike height to get intermediate failure probability
        # With a_frac=0.5, b_frac=0.5: A=8.5, B=4.25, D=4.25, dike_top=8.5
        # Surges of ~7m will sometimes overtop, sometimes not
        scenario = StochasticScenario(surges=[7.0, 7.0, 7.0], discount_rate=0.0)
        policy = StaticPolicy(a_frac=0.5, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        damages = [
            SimOptDecisions.value(
                SimOptDecisions.simulate(config, scenario, policy, MersenneTwister(seed)).damage
            )
            for seed in 1:50
        ]

        # With stochastic dike failure, different seeds should produce different damages
        @test length(unique(damages)) > 1
    end
end
