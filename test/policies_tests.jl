using Test
using ICOW
using Distributions

@testset "Policy Types" begin

    @testset "StaticPolicy" begin
        @testset "Construction" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            policy = StaticPolicy(levers)

            @test policy.levers === levers
            @test policy isa StaticPolicy{Float64}
            @test policy isa AbstractPolicy{Float64}
        end

        @testset "Callable interface" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            policy = StaticPolicy(levers)

            # Create dummy state and forcing for the call
            state = StochasticState(Levers(0.0, 0.0, 0.0, 0.0, 0.0))
            forcing = StochasticForcing(rand(10, 5), 2020)

            # Calling policy returns the fixed levers
            result = policy(state, forcing, 1)
            @test result === levers

            # Returns same levers regardless of year
            @test policy(state, forcing, 1) === levers
            @test policy(state, forcing, 5) === levers

            # Returns same levers regardless of state
            state2 = StochasticState(Levers(5.0, 5.0, 0.9, 5.0, 5.0))
            @test policy(state2, forcing, 1) === levers
        end

        @testset "parameters extraction" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            policy = StaticPolicy(levers)

            params = parameters(policy)

            @test params isa Vector{Float64}
            @test length(params) == 5
            @test params[1] == 1.0  # W
            @test params[2] == 2.0  # R
            @test params[3] == 0.5  # P
            @test params[4] == 3.0  # D
            @test params[5] == 1.0  # B
        end

        @testset "Single precision" begin
            levers = Levers(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
            policy = StaticPolicy(levers)

            @test policy isa StaticPolicy{Float32}

            params = parameters(policy)
            @test params isa Vector{Float32}
        end

        @testset "Type stability" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            policy = StaticPolicy(levers)
            state = StochasticState(Levers(0.0, 0.0, 0.0, 0.0, 0.0))
            forcing = StochasticForcing(rand(10, 5), 2020)

            # Callable is type stable
            @test @inferred(policy(state, forcing, 1)) isa Levers{Float64}

            # parameters is type stable
            @test @inferred(parameters(policy)) isa Vector{Float64}
        end
    end

end
