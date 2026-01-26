using ICOW
using Test
using Random
using Distributions

@testset "ICOW.jl" begin
    # Core types (FloodDefenses)
    include("types_tests.jl")

    # Core physics functions (validated against debugged C++ reference)
    include("core/cpp_validation_tests.jl")

    # Stochastic submodule
    @testset "Stochastic" begin
        include("stochastic/types_tests.jl")
        include("stochastic/simulation_tests.jl")
    end

    # EAD submodule
    @testset "EAD" begin
        include("ead/types_tests.jl")
        include("ead/simulation_tests.jl")
    end

    # Package quality checks
    include("test_aqua.jl")
end
