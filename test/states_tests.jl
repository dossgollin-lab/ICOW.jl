using Test
using ICOW

@testset "State Types" begin

    @testset "StochasticState" begin
        @testset "Construction with convenience constructor" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            state = StochasticState(levers)

            # Levers stored correctly
            @test state.current_levers === levers

            # Accumulators initialized to zero
            @test state.accumulated_cost == 0.0
            @test state.accumulated_damage == 0.0

            # Year initialized to 1
            @test state.current_year == 1

            # Type stability
            @test state isa StochasticState{Float64}
        end

        @testset "Full constructor" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            state = StochasticState(levers, 100.0, 50.0, 5)

            @test state.current_levers === levers
            @test state.accumulated_cost == 100.0
            @test state.accumulated_damage == 50.0
            @test state.current_year == 5
        end

        @testset "Mutability" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            state = StochasticState(levers)

            # Can update accumulators in-place
            state.accumulated_cost = 1000.0
            @test state.accumulated_cost == 1000.0

            state.accumulated_damage = 500.0
            @test state.accumulated_damage == 500.0

            state.current_year = 10
            @test state.current_year == 10

            # Can update levers
            new_levers = Levers(2.0, 3.0, 0.6, 4.0, 2.0)
            state.current_levers = new_levers
            @test state.current_levers === new_levers
        end

        @testset "Single precision" begin
            levers = Levers(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
            state = StochasticState(levers)

            @test state isa StochasticState{Float32}
            @test state.accumulated_cost isa Float32
            @test state.accumulated_damage isa Float32
        end

        @testset "Abstract type hierarchy" begin
            levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
            state = StochasticState(levers)

            @test state isa AbstractSimulationState{Float64}
            @test state isa AbstractSimulationState
        end
    end

    @testset "EADState" begin
        @testset "Construction with convenience constructor" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            state = EADState(levers)

            # Levers stored correctly
            @test state.current_levers === levers

            # Accumulators initialized to zero
            @test state.accumulated_cost == 0.0
            @test state.accumulated_ead == 0.0

            # Year initialized to 1
            @test state.current_year == 1

            # Type stability
            @test state isa EADState{Float64}
        end

        @testset "Full constructor" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            state = EADState(levers, 100.0, 50.0, 5)

            @test state.current_levers === levers
            @test state.accumulated_cost == 100.0
            @test state.accumulated_ead == 50.0
            @test state.current_year == 5
        end

        @testset "Mutability" begin
            levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            state = EADState(levers)

            # Can update accumulators in-place
            state.accumulated_cost = 1000.0
            @test state.accumulated_cost == 1000.0

            state.accumulated_ead = 500.0
            @test state.accumulated_ead == 500.0

            state.current_year = 10
            @test state.current_year == 10
        end

        @testset "Abstract type hierarchy" begin
            levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
            state = EADState(levers)

            @test state isa AbstractSimulationState{Float64}
            @test state isa AbstractSimulationState
        end
    end

end
