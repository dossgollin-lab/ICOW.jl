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
        outcome = simulate(config, scenario, policy, rng)

        @test outcome isa StochasticOutcome
        @test SimOptDecisions.value(outcome.investment) > 0.0
        @test SimOptDecisions.value(outcome.damage) >= 0.0
    end

    @testset "Zero policy produces zero investment" begin
        config = StochasticConfig()
        scenario = StochasticScenario(surges=[1.0, 2.0], discount_rate=0.0)
        policy = StaticPolicy(a_frac=0.0, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)

        rng = MersenneTwister(42)
        outcome = simulate(config, scenario, policy, rng)

        @test SimOptDecisions.value(outcome.investment) == 0.0
    end

    @testset "Deterministic with same RNG" begin
        config = StochasticConfig()
        scenario = StochasticScenario(surges=[1.0, 2.0, 3.0, 4.0, 5.0], discount_rate=0.03)
        policy = StaticPolicy(a_frac=0.5, w_frac=0.1, b_frac=0.3, r_frac=0.2, P=0.5)

        outcome1 = simulate(config, scenario, policy, MersenneTwister(123))
        outcome2 = simulate(config, scenario, policy, MersenneTwister(123))

        @test SimOptDecisions.value(outcome1.investment) == SimOptDecisions.value(outcome2.investment)
        @test SimOptDecisions.value(outcome1.damage) == SimOptDecisions.value(outcome2.damage)
    end

    @testset "Discounting applied correctly" begin
        config = StochasticConfig()
        scenario_no_discount = StochasticScenario(surges=[1.0, 2.0, 3.0], discount_rate=0.0)
        scenario_with_discount = StochasticScenario(surges=[1.0, 2.0, 3.0], discount_rate=0.1)
        policy = StaticPolicy(a_frac=0.3, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        outcome_no = simulate(config, scenario_no_discount, policy, MersenneTwister(42))
        outcome_yes = simulate(config, scenario_with_discount, policy, MersenneTwister(42))

        # With positive discount rate, NPV should be lower (future costs worth less)
        @test total_cost(outcome_yes) < total_cost(outcome_no)
    end

    @testset "Stochastic dike failure produces variation" begin
        config = StochasticConfig()
        # Moderate surges near dike height to get intermediate failure probability
        # With a_frac=0.5, b_frac=0.5: A=8.5, B=4.25, D=4.25, dike_top=8.5
        # Surges of ~7m will sometimes overtop, sometimes not
        scenario = StochasticScenario(surges=[7.0, 7.0, 7.0], discount_rate=0.0)
        policy = StaticPolicy(a_frac=0.5, w_frac=0.0, b_frac=0.5, r_frac=0.0, P=0.0)

        damages = [
            SimOptDecisions.value(simulate(config, scenario, policy, MersenneTwister(seed)).damage)
            for seed in 1:50
        ]

        # With stochastic dike failure, different seeds should produce different damages
        @test length(unique(damages)) > 1
    end

    @testset "Infeasible policy returns infinite costs" begin
        config = StochasticConfig()  # H_city = 17.0
        scenario = StochasticScenario(surges=[1.0, 2.0], discount_rate=0.0)
        # a_frac=1, w_frac=1 produces W = H_city, which is infeasible (strict inequality required)
        policy = StaticPolicy(a_frac=1.0, w_frac=1.0, b_frac=0.0, r_frac=0.0, P=0.0)

        outcome = simulate(config, scenario, policy, MersenneTwister(42))

        @test SimOptDecisions.value(outcome.investment) == Inf
        @test SimOptDecisions.value(outcome.damage) == Inf
    end
end
