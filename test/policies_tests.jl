using Test
using ICOW

@testset "StaticPolicy" begin
    levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
    policy = StaticPolicy(levers)

    @test policy.levers === levers
    @test policy isa AbstractPolicy{Float64}

    # Callable: returns fixed levers regardless of state/year
    state = StochasticState(Levers(0.0, 0.0, 0.0, 0.0, 0.0))
    forcing = StochasticForcing(rand(10, 5), 2020)
    @test policy(state, forcing, 1) === levers
    @test policy(state, forcing, 5) === levers

    # Parameters extraction
    params = parameters(policy)
    @test params == [1.0, 2.0, 0.5, 3.0, 1.0]

    # Type stability
    @test (@inferred policy(state, forcing, 1)) isa Levers{Float64}
    @test (@inferred parameters(policy)) isa Vector{Float64}

    # Single precision
    levers32 = Levers(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
    policy32 = StaticPolicy(levers32)
    @test policy32 isa StaticPolicy{Float32}
    @test parameters(policy32) isa Vector{Float32}
end
