using ICOW
using Test

@testset "FloodDefenses" begin
    # Valid construction
    defenses = FloodDefenses(5.0, 2.0, 0.5, 5.0, 2.0)
    @test defenses.W == 5.0 && defenses.R == 2.0 && defenses.P == 0.5

    # Type parameterization and promotion
    @test FloodDefenses{Float32}(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0).W isa Float32
    @test FloodDefenses(1, 2, 0.5, 3, 1).W isa Float64  # Promotion

    # Constraint validation
    @test_throws AssertionError FloodDefenses(-1.0, 0.0, 0.0, 0.0, 0.0)  # W >= 0
    @test_throws AssertionError FloodDefenses(0.0, -1.0, 0.0, 0.0, 0.0)  # R >= 0
    @test_throws AssertionError FloodDefenses(0.0, 0.0, 1.0, 0.0, 0.0)   # P < 1.0
    @test_throws AssertionError FloodDefenses(0.0, 0.0, -0.1, 0.0, 0.0)  # P >= 0
    @test_throws AssertionError FloodDefenses(0.0, 0.0, 0.0, -1.0, 0.0)  # D >= 0
    @test_throws AssertionError FloodDefenses(0.0, 0.0, 0.0, 0.0, -1.0)  # B >= 0

    # P boundary: 0.999 valid, 1.0 invalid
    @test FloodDefenses(0.0, 0.0, 0.999, 0.0, 0.0).P == 0.999
end

@testset "FloodDefenses max" begin
    a = FloodDefenses(1.0, 2.0, 0.3, 4.0, 1.0)
    b = FloodDefenses(2.0, 1.0, 0.5, 3.0, 2.0)
    result = max(a, b)

    @test result.W == 2.0 && result.R == 2.0 && result.P == 0.5
    @test result.D == 4.0 && result.B == 2.0
end

@testset "FloodDefenses Type Stability" begin
    defenses = FloodDefenses(1.0, 2.0, 0.5, 3.0, 1.0)
    @test (@inferred max(defenses, defenses)) isa FloodDefenses{Float64}
end
