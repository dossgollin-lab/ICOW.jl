using Test
using ICOW
using Distributions
using BlackBoxOptim

@testset "Optimization" begin
    city = CityParameters()

    @testset "valid_bounds" begin
        (lower, upper) = valid_bounds(StaticPolicy, city)

        # correct structure: 5 bounds for [W, R, P, D, B]
        @test length(lower) == 5
        @test length(upper) == 5

        # lower <= upper for all parameters
        @test all(lower .<= upper)

        # bounds match expected values
        @test lower == (0.0, 0.0, 0.0, 0.0, 0.0)
        @test upper == (city.H_city, city.H_city, 0.99, city.H_city, city.H_city)
    end

    @testset "optimize runs without error" begin
        # Use distributional forcing for faster optimization
        forcing = DistributionalForcing([Normal(1.5, 0.5) for _ in 1:5], 2020)

        # Suppress BlackBoxOptim epsilon-box warnings (harmless, from third-party package)
        result = Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
            optimize(city, [forcing], 0.03; max_steps=10, population_size=10)
        end

        # Pareto frontier should have at least one solution
        @test !isempty(pareto_frontier(result))

        # Should be able to extract policies
        policies = pareto_policies(result, StaticPolicy)
        @test length(policies) >= 1
        @test all(p -> p isa StaticPolicy, policies)

        # best_total should return a valid policy
        best = best_total(result, StaticPolicy)
        @test best isa StaticPolicy
    end

    @testset "discount_rate in simulate" begin
        forcing = DistributionalForcing([Normal(1.5, 0.5) for _ in 1:5], 2020)
        policy = StaticPolicy(Levers(0.0, 0.0, 0.0, 5.0, 0.0))

        # no discounting
        (inv0, dmg0) = simulate(city, policy, forcing; discount_rate=0.0)

        # with discounting, NPV should be less than undiscounted sum
        (inv_d, dmg_d) = simulate(city, policy, forcing; discount_rate=0.05)

        @test inv_d < inv0
        @test dmg_d < dmg0
    end
end
