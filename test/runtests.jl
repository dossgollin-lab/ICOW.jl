using ICOW
using Test

@testset "ICOW.jl" begin
    # Phase 0: Parameters & Validation
    include("parameters_tests.jl")
    include("types_tests.jl")
end
