using Test
using ICOW
import SimOptDecisions

@testset "StaticPolicy" begin
    levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
    policy = StaticPolicy(levers)

    @test policy.levers === levers
    @test policy isa SimOptDecisions.AbstractPolicy

    # Callable: returns fixed levers in year 1, zero levers otherwise
    state = State(Levers(0.0, 0.0, 0.0, 0.0, 0.0))
    forcing = StochasticForcing(rand(10, 5), 2020)
    zero_levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
    @test policy(state, forcing, 1) === levers
    @test policy(state, forcing, 2) == zero_levers

    # Parameters extraction
    params = parameters(policy)
    @test params == [1.0, 2.0, 0.5, 3.0, 1.0]

    # Type stability
    @test (@inferred policy(state, forcing, 1)) isa Levers{Float64}
    @test (@inferred parameters(policy)) isa Vector{Float64}
end

@testset "Round-Trip: parameters ↔ StaticPolicy" begin
    original_levers = Levers(2.0, 1.5, 0.3, 4.0, 2.5)
    original_policy = StaticPolicy(original_levers)

    params = parameters(original_policy)
    reconstructed = StaticPolicy(params)

    @test reconstructed.levers == original_levers
    @test typeof(reconstructed) === typeof(original_policy)
    @test parameters(reconstructed) == params

    # Invalid input: wrong number of parameters
    @test_throws AssertionError StaticPolicy([1.0, 2.0, 3.0])
    @test_throws AssertionError StaticPolicy([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
end

@testset "Both Simulation Modes" begin
    city = CityParameters()
    policy = StaticPolicy(Levers(1.0, 0.0, 0.2, 2.0, 3.0))

    # Stochastic mode
    surges_stochastic = reshape([0.5, 1.0, 1.5, 2.0, 2.5], 1, 5)
    forcing_stochastic = StochasticForcing(surges_stochastic, 2020)

    investment_s, damage_s = simulate(city, policy, forcing_stochastic; mode=:scalar)
    @test investment_s >= 0
    @test damage_s >= 0

    # EAD mode
    ead_dist = [truncated(Normal(0.0, 1.0), lower=0.0) for _ in 1:5]
    forcing_ead = DistributionalForcing(ead_dist, 2020)

    investment_e, damage_e = simulate(city, policy, forcing_ead; mode=:scalar)
    @test investment_e >= 0
    @test damage_e >= 0
end
