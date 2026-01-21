using Test
using ICOW
import SimOptDecisions
using Distributions
using Random

@testset "Optimization" begin
    city = CityParameters()

    @testset "param_bounds" begin
        bounds = SimOptDecisions.param_bounds(StaticPolicy)

        # correct structure: 5 bounds for [W, R, P, D, B]
        @test length(bounds) == 5
        @test all(b -> b[1] <= b[2], bounds)
    end

    @testset "FeasibilityConstraint" begin
        # Feasible policy
        feasible = StaticPolicy(Levers(1.0, 2.0, 0.5, 3.0, 2.0))
        @test is_feasible(feasible.levers, city)

        # Infeasible policy (W > B)
        infeasible = StaticPolicy(Levers(5.0, 0.0, 0.0, 3.0, 2.0))
        @test !is_feasible(infeasible.levers, city)
    end

    @testset "Discount rate in scenario" begin
        forcing = DistributionalForcing([Normal(1.5, 0.5) for _ in 1:5])
        policy = StaticPolicy(Levers(0.0, 0.0, 0.0, 5.0, 0.0))
        rng = MersenneTwister(42)

        # No discounting
        scenario0 = EADScenario(forcing; discount_rate=0.0)
        result0 = SimOptDecisions.simulate(city, scenario0, policy, rng)

        # With discounting
        rng2 = MersenneTwister(42)
        scenario_d = EADScenario(forcing; discount_rate=0.05)
        result_d = SimOptDecisions.simulate(city, scenario_d, policy, rng2)

        # Investment in year 1 is similar (discount factor ~1.0 for year 1)
        # But damage NPV should be less with discounting
        @test result_d.damage < result0.damage
    end
end
