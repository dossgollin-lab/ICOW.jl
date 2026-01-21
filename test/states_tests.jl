using Test
using ICOW
import SimOptDecisions

@testset "State Types" begin
    levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)

    @testset "State" begin
        # Default constructor: sea level = 0
        state = State(levers)
        @test state.current_levers === levers
        @test state.current_sea_level == 0.0
        @test state isa SimOptDecisions.AbstractState

        # With explicit sea level
        state2 = State(levers, 0.5)
        @test state2.current_sea_level == 0.5

        # Mutability
        state.current_sea_level = 1.0
        @test state.current_sea_level == 1.0
    end

    @testset "Type Stability" begin
        levers32 = Levers(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
        @test State(levers32) isa State{Float32}
    end
end
