using ICOW
using Test

@testset "ICOW.jl" begin
    # Phase 1: Parameters & Validation
    include("parameters_tests.jl")
    include("types_tests.jl")

    # Phase 2: Type System & Simulation Modes
    include("forcing_tests.jl")
    include("states_tests.jl")
    include("policies_tests.jl")

    # Phase 3: Geometry
    include("geometry_tests.jl")

    # Phase 4: Costs and Dike Failure
    include("costs_tests.jl")
end
