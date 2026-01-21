using Test
using ICOW
import SimOptDecisions
using Random
using Distributions

@testset "StaticPolicy" begin
    levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
    policy = StaticPolicy(levers)

    @test policy.levers === levers
    @test policy isa SimOptDecisions.AbstractPolicy

    # Callable: returns fixed levers in year 1, zero levers otherwise
    state = State(Levers(0.0, 0.0, 0.0, 0.0, 0.0))
    forcing = StochasticForcing(rand(10, 5))
    @test policy(state, forcing, 1) === levers
    @test policy(state, forcing, 2) == Levers(0.0, 0.0, 0.0, 0.0, 0.0)

    # SimOptDecisions.params
    params = SimOptDecisions.params(policy)
    @test params == [1.0, 2.0, 0.5, 3.0, 1.0]

    # Type stability
    @test (@inferred policy(state, forcing, 1)) isa Levers{Float64}
end

@testset "Round-trip: params <-> StaticPolicy" begin
    original = StaticPolicy(Levers(2.0, 1.5, 0.3, 4.0, 2.5))

    params = SimOptDecisions.params(original)
    reconstructed = StaticPolicy(params)

    @test reconstructed.levers == original.levers
    @test SimOptDecisions.params(reconstructed) == params

    # Invalid input
    @test_throws AssertionError StaticPolicy([1.0, 2.0, 3.0])
    @test_throws AssertionError StaticPolicy([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
end

@testset "Both scenario types" begin
    city = CityParameters()
    policy = StaticPolicy(Levers(1.0, 0.0, 0.2, 2.0, 3.0))
    rng = MersenneTwister(42)

    # Stochastic
    stoch = StochasticScenario(StochasticForcing(reshape([0.5, 1.0, 1.5, 2.0, 2.5], 1, 5)), 1)
    result_s = SimOptDecisions.simulate(city, stoch, policy, rng)
    @test result_s.investment >= 0
    @test result_s.damage >= 0

    # EAD
    ead = EADScenario(DistributionalForcing([truncated(Normal(0.0, 1.0), lower=0.0) for _ in 1:5]))
    result_e = SimOptDecisions.simulate(city, ead, policy, rng)
    @test result_e.investment >= 0
    @test result_e.damage >= 0
end
