using Test
using ICOW

@testset "StaticPolicy" begin
    levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
    policy = StaticPolicy(levers)

    @test policy.levers === levers
    @test policy isa AbstractPolicy{Float64}

    # Callable: returns fixed levers in year 1, zero levers otherwise
    state = StochasticState(Levers(0.0, 0.0, 0.0, 0.0, 0.0))
    forcing = StochasticForcing(rand(10, 5), 2020)
    zero_levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
    @test policy(state, forcing, 1) === levers
    @test policy(state, forcing, 2) == zero_levers
    @test policy(state, forcing, 5) == zero_levers

    # Parameters extraction
    params = parameters(policy)
    @test params == [1.0, 2.0, 0.5, 3.0, 1.0]

    # Type stability
    @test (@inferred policy(state, forcing, 1)) isa Levers{Float64}
    @test (@inferred policy(state, forcing, 2)) isa Levers{Float64}
    @test (@inferred parameters(policy)) isa Vector{Float64}

    # Single precision
    levers32 = Levers(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
    policy32 = StaticPolicy(levers32)
    @test policy32 isa StaticPolicy{Float32}
    @test parameters(policy32) isa Vector{Float32}
end

@testset "Round-Trip: parameters ↔ StaticPolicy" begin
    # Float64: policy → parameters → policy
    original_levers = Levers(2.0, 1.5, 0.3, 4.0, 2.5)
    original_policy = StaticPolicy(original_levers)

    params = parameters(original_policy)
    reconstructed = StaticPolicy(params)

    @test reconstructed.levers == original_levers
    @test typeof(reconstructed) === typeof(original_policy)
    @test parameters(reconstructed) == params

    # Float32: policy → parameters → policy
    original_levers32 = Levers(2.0f0, 1.5f0, 0.3f0, 4.0f0, 2.5f0)
    original_policy32 = StaticPolicy(original_levers32)

    params32 = parameters(original_policy32)
    reconstructed32 = StaticPolicy(params32)

    @test reconstructed32.levers == original_levers32
    @test typeof(reconstructed32) === typeof(original_policy32)
    @test parameters(reconstructed32) == params32

    # Invalid input: wrong number of parameters
    @test_throws AssertionError StaticPolicy([1.0, 2.0, 3.0])  # 3 ≠ 5
    @test_throws AssertionError StaticPolicy([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])  # 6 ≠ 5
end

@testset "Both Simulation Modes" begin
    # Create simple test scenario using defaults
    city = CityParameters()

    policy = StaticPolicy(Levers(1.0, 0.0, 0.2, 2.0, 3.0))

    # Stochastic mode (matrix: [n_scenarios=1, n_years=5])
    surges_stochastic = reshape([0.5, 1.0, 1.5, 2.0, 2.5], 1, 5)
    forcing_stochastic = StochasticForcing(surges_stochastic, 2020)

    investment_s, damage_s = simulate(city, policy, forcing_stochastic; mode=:scalar)
    @test investment_s isa Real
    @test damage_s isa Real
    @test investment_s >= 0
    @test damage_s >= 0

    # EAD mode
    ead_dist = [truncated(Normal(0.0, 1.0), lower=0.0) for _ in 1:5]
    forcing_ead = DistributionalForcing(ead_dist, 2020)

    investment_e, damage_e = simulate(city, policy, forcing_ead; mode=:scalar)
    @test investment_e isa Real
    @test damage_e isa Real
    @test investment_e >= 0
    @test damage_e >= 0

    # Both modes should handle the same policy consistently
    state_s = StochasticState(Levers(0.0, 0.0, 0.0, 0.0, 0.0))
    state_e = EADState(Levers(0.0, 0.0, 0.0, 0.0, 0.0))

    # Year 1: returns policy levers
    levers_s1 = policy(state_s, forcing_stochastic, 1)
    levers_e1 = policy(state_e, forcing_ead, 1)
    @test levers_s1 == levers_e1
    @test levers_s1 == policy.levers

    # Year > 1: returns zero levers
    levers_s2 = policy(state_s, forcing_stochastic, 2)
    levers_e2 = policy(state_e, forcing_ead, 2)
    zero_levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
    @test levers_s2 == levers_e2
    @test levers_s2 == zero_levers
end
