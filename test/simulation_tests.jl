using Test
using ICOW
import SimOptDecisions
using Random
using Distributions

@testset "Simulation Callbacks" begin
    city = CityParameters{Float64}()

    # Create forcing data
    surges = rand(MersenneTwister(123), 10, 5) .* 3.0
    stoch_forcing = StochasticForcing(surges)
    dists = [Normal(1.5, 0.5) for _ in 1:5]
    dist_forcing = DistributionalForcing(dists)

    # Create scenarios
    stoch_scenario = StochasticScenario(stoch_forcing, 1; discount_rate=0.03)
    ead_scenario = EADScenario(dist_forcing; discount_rate=0.03)

    # Policy
    policy = StaticPolicy(Levers(0.0, 0.0, 0.0, 5.0, 0.0))

    @testset "Stochastic simulation" begin
        rng = MersenneTwister(42)
        result = SimOptDecisions.simulate(city, stoch_scenario, policy, rng)

        @test haskey(result, :investment)
        @test haskey(result, :damage)
        @test result.investment >= 0.0
        @test result.damage >= 0.0
    end

    @testset "EAD simulation" begin
        rng = MersenneTwister(42)
        result = SimOptDecisions.simulate(city, ead_scenario, policy, rng)

        @test haskey(result, :investment)
        @test haskey(result, :damage)
        @test result.investment >= 0.0
        @test result.damage >= 0.0
    end

    @testset "Irreversibility" begin
        # Policy that tries to decrease protection
        struct DecreasingPolicy <: SimOptDecisions.AbstractPolicy end
        function (::DecreasingPolicy)(state, forcing, year)
            year <= 2 ? Levers(0.0, 0.0, 0.0, 5.0, 0.0) : Levers(0.0, 0.0, 0.0, 2.0, 0.0)
        end

        builder = SimOptDecisions.TraceRecorderBuilder()
        SimOptDecisions.simulate(city, stoch_scenario, DecreasingPolicy(), builder, MersenneTwister(42))
        trace = SimOptDecisions.build_trace(builder)

        # Verify D never decreases
        for i in 2:length(trace.states)
            @test trace.states[i].current_levers.D >= trace.states[i-1].current_levers.D
        end
        # Should stay at 5.0 (not decrease to 2.0)
        @test all(s -> s.current_levers.D == 5.0, trace.states)
    end

    @testset "Marginal costing" begin
        builder = SimOptDecisions.TraceRecorderBuilder()
        SimOptDecisions.simulate(city, stoch_scenario, policy, builder, MersenneTwister(42))
        trace = SimOptDecisions.build_trace(builder)

        # First year has investment, subsequent years have zero
        @test trace.step_records[1].investment > 0.0
        for i in 2:length(trace.step_records)
            @test trace.step_records[i].investment == 0.0
        end
    end

    @testset "Discounting in compute_outcome" begin
        # With discount rate > 0, NPV should be less than undiscounted sum
        scenario_disc = StochasticScenario(stoch_forcing, 1; discount_rate=0.1)
        scenario_nodisc = StochasticScenario(stoch_forcing, 1; discount_rate=0.0)

        rng1, rng2 = MersenneTwister(42), MersenneTwister(42)
        result_disc = SimOptDecisions.simulate(city, scenario_disc, policy, rng1)
        result_nodisc = SimOptDecisions.simulate(city, scenario_nodisc, policy, rng2)

        # Discounted values should be less (investment is in year 1, so similar, but damage differs)
        @test result_disc.damage <= result_nodisc.damage
    end
end
