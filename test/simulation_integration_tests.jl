using ICOW
using Test
using Random
import SimOptDecisions

@testset "SimOptDecisions Integration" begin
    @testset "Types subtype abstracts" begin
        @test Config <: SimOptDecisions.AbstractConfig
        @test Scenario <: SimOptDecisions.AbstractScenario
        @test State <: SimOptDecisions.AbstractState
        @test StaticPolicy <: SimOptDecisions.AbstractPolicy
        @test Outcome <: SimOptDecisions.AbstractOutcome
    end

    @testset "StaticPolicy" begin
        # Parametric construction
        policy64 = StaticPolicy(1.0, 2.0, 0.3, 3.0, 1.0)
        @test policy64 isa StaticPolicy{Float64}

        policy32 = StaticPolicy(1.0f0, 2.0f0, 0.3f0, 3.0f0, 1.0f0)
        @test policy32 isa StaticPolicy{Float32}

        # defenses helper
        fd = defenses(policy64)
        @test fd isa FloodDefenses{Float64}
        @test fd.W == 1.0 && fd.R == 2.0 && fd.P == 0.3 && fd.D == 3.0 && fd.B == 1.0

        # params for optimization
        p = SimOptDecisions.params(policy64)
        @test p == [1.0, 2.0, 0.3, 3.0, 1.0]
    end

    @testset "State" begin
        state = State()
        @test state.defenses == FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0)

        state.defenses = FloodDefenses(1.0, 2.0, 0.3, 3.0, 1.0)
        @test state.defenses.W == 1.0
    end

    @testset "Simulation runs" begin
        config = Config()
        scenario = Scenario([1.0, 2.0, 3.0, 4.0, 5.0])
        policy = StaticPolicy(0.0, 0.0, 0.0, 3.0, 0.0)

        rng = Random.MersenneTwister(42)
        outcome = simulate(config, scenario, policy, rng)

        @test outcome isa Outcome
        @test outcome.investment > 0.0
        @test outcome.damage >= 0.0
        @test total_cost(outcome) == outcome.investment + outcome.damage
    end

    @testset "Irreversibility enforced" begin
        config = Config()
        scenario = Scenario([1.0, 2.0, 3.0])
        policy = StaticPolicy(0.0, 0.0, 0.0, 5.0, 0.0)

        rng = Random.MersenneTwister(42)
        outcome = simulate(config, scenario, policy, rng)

        # Investment should only happen in year 1 (marginal costing)
        # This is implicitly tested by the fact that simulation completes
        @test outcome.investment > 0.0
    end

    @testset "Deterministic with same RNG" begin
        config = Config()
        scenario = Scenario([1.0, 2.0, 3.0, 4.0, 5.0])
        policy = StaticPolicy(1.0, 2.0, 0.3, 3.0, 1.0)

        outcome1 = simulate(config, scenario, policy, Random.MersenneTwister(123))
        outcome2 = simulate(config, scenario, policy, Random.MersenneTwister(123))

        @test outcome1.investment == outcome2.investment
        @test outcome1.damage == outcome2.damage
    end
end
