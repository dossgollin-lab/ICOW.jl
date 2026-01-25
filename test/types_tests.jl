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

@testset "is_feasible" begin
    city = CityParameters()  # H_city = 17.0

    # Feasible
    @test is_feasible(FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0), city)
    @test is_feasible(FloodDefenses(17.0, 0.0, 0.0, 0.0, 0.0), city)  # W = H_city

    # Infeasible
    @test !is_feasible(FloodDefenses(18.0, 0.0, 0.0, 0.0, 0.0), city)  # W > H_city
    @test !is_feasible(FloodDefenses(10.0, 0.0, 0.0, 5.0, 5.0), city)  # W+B+D > H_city
end

@testset "FloodDefenses max" begin
    a = FloodDefenses(1.0, 2.0, 0.3, 4.0, 1.0)
    b = FloodDefenses(2.0, 1.0, 0.5, 3.0, 2.0)
    result = max(a, b)

    @test result.W == 2.0 && result.R == 2.0 && result.P == 0.5
    @test result.D == 4.0 && result.B == 2.0
end

@testset "validate_parameters" begin
    # Valid parameters pass without error
    city = CityParameters()
    @test validate_parameters(city) === nothing

    # V_city > 0; city value must be positive
    @test_throws AssertionError validate_parameters(CityParameters(V_city=-1.0))
    @test_throws AssertionError validate_parameters(CityParameters(V_city=0.0))

    # Fractions in [0, 1]
    @test_throws AssertionError validate_parameters(CityParameters(f_damage=1.5))
    @test_throws AssertionError validate_parameters(CityParameters(t_fail=-0.1))

    # f_runup >= 1.0; runup should amplify
    @test_throws AssertionError validate_parameters(CityParameters(f_runup=0.9))
end

@testset "Type Stability" begin
    city = CityParameters()
    defenses = FloodDefenses(1.0, 2.0, 0.5, 3.0, 1.0)
    @test (@inferred is_feasible(defenses, city)) isa Bool
    @test (@inferred max(defenses, defenses)) isa FloodDefenses{Float64}
end
