using ICOW
using Test
using Random

@testset "ICOW.jl" begin
    # Core types (FloodDefenses)
    include("types_tests.jl")

    # Stochastic submodule
    @testset "Stochastic" begin
        include("stochastic/types_tests.jl")
        include("stochastic/simulation_tests.jl")
    end
end
