using ICOW
using Test
using Random

@testset "ICOW.jl" begin
    # Core types
    include("types_tests.jl")

    # SimOptDecisions integration
    include("simulation_integration_tests.jl")
end
