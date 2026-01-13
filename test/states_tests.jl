using Test
using ICOW
import SimOptDecisions

@testset "State Types" begin
    levers = Levers(1.0, 2.0, 0.5, 3.0, 1.0)

    @testset "State" begin
        state = State(levers)
        @test state.current_levers === levers
        @test state.current_year == 1
        @test state isa SimOptDecisions.AbstractState

        # Mutability
        state.current_year = 5
        @test state.current_year == 5
    end

    @testset "Type Stability" begin
        levers32 = Levers(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
        @test State(levers32) isa State{Float32}
    end
end
