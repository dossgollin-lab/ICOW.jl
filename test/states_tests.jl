using Test
using ICOW

@testset "State Types" begin
    levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)

    @testset "StochasticState" begin
        state = StochasticState(levers)
        @test state.current_levers === levers
        @test state.accumulated_cost == 0.0
        @test state.accumulated_damage == 0.0
        @test state.current_year == 1
        @test state isa AbstractSimulationState{Float64}

        # Mutability
        state.accumulated_cost = 1000.0
        @test state.accumulated_cost == 1000.0
    end

    @testset "EADState" begin
        state = EADState(levers)
        @test state.current_levers === levers
        @test state.accumulated_cost == 0.0
        @test state.accumulated_ead == 0.0
        @test state.current_year == 1
        @test state isa AbstractSimulationState{Float64}

        # Mutability
        state.accumulated_ead = 500.0
        @test state.accumulated_ead == 500.0
    end

    @testset "Type Stability" begin
        levers32 = Levers(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
        @test StochasticState(levers32) isa StochasticState{Float32}
    end
end
