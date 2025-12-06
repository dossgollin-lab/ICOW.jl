using Test

@testset "Levers Construction" begin
    # Valid construction with individual arguments
    levers = Levers(2.0, 3.0, 0.5, 5.0, 4.0)
    @test levers.withdraw_h == 2.0
    @test levers.resist_h == 3.0
    @test levers.resist_p == 0.5
    @test levers.dike_h == 5.0
    @test levers.dike_base_h == 4.0

    # Construction from vector
    x = [2.0, 3.0, 0.5, 5.0, 4.0]
    levers_vec = Levers(x)
    @test levers_vec.withdraw_h == 2.0
    @test levers_vec.resist_h == 3.0
    @test levers_vec.resist_p == 0.5
    @test levers_vec.dike_h == 5.0
    @test levers_vec.dike_base_h == 4.0

    # All zeros should be valid
    levers_zero = Levers(0, 0, 0, 0, 0)
    @test all([levers_zero.withdraw_h, levers_zero.resist_h, levers_zero.resist_p,
               levers_zero.dike_h, levers_zero.dike_base_h] .== 0.0)
end

@testset "Levers Constraints" begin
    # Valid levers should pass all constraints
    levers = Levers(2.0, 3.0, 0.5, 5.0, 4.0)
    city = CityParameters()
    @test is_feasible(levers, city)

    # B + D ≤ city_max_height; dike cannot extend above the city's highest point
    @test_throws AssertionError Levers(0, 0, 0, 10.0, 10.0)

    # W ≤ B; cannot withdraw from areas above the dike base (they're protected)
    @test_throws AssertionError Levers(5.0, 0, 0, 5.0, 2.0)

    # 0 ≤ P ≤ 1; resistance percentage must be a valid fraction
    @test_throws AssertionError Levers(0, 0, 1.5, 0, 0)
    @test_throws AssertionError Levers(0, 0, -0.1, 0, 0)

    # W, R, D, B ≥ 0; all heights must be non-negative (physical constraint)
    @test_throws AssertionError Levers(-1.0, 0, 0, 0, 0)
    @test_throws AssertionError Levers(0, -1.0, 0, 0, 0)
    @test_throws AssertionError Levers(0, 0, 0, -1.0, 0)
    @test_throws AssertionError Levers(0, 0, 0, 0, -1.0)
end

@testset "Levers Validation Disabled" begin
    # When validation is disabled, invalid constraints should not throw
    invalid_levers = Levers(10.0, 0, 0, 20.0, 15.0; validate=false)
    @test invalid_levers.withdraw_h == 10.0
    @test invalid_levers.dike_h == 20.0
    @test invalid_levers.dike_base_h == 15.0

    # But is_feasible should still detect violations
    city = CityParameters()
    @test !is_feasible(invalid_levers, city)
end

@testset "Levers Boundary Cases" begin
    city = CityParameters()

    # W = B is valid (withdrawal exactly at dike base)
    levers_boundary = Levers(4.0, 0, 0, 5.0, 4.0)
    @test is_feasible(levers_boundary, city)

    # B + D = H_city is valid (dike exactly at city top)
    levers_max_dike = Levers(0, 0, 0, 7.0, 10.0)
    @test is_feasible(levers_max_dike, city)

    # P = 0 and P = 1 are valid
    levers_p0 = Levers(0, 3.0, 0.0, 0, 0)
    @test is_feasible(levers_p0, city)

    levers_p1 = Levers(0, 3.0, 1.0, 0, 0)
    @test is_feasible(levers_p1, city)
end

@testset "Levers max() Function" begin
    # Element-wise maximum
    l1 = Levers(1.0, 2.0, 0.3, 4.0, 3.0)
    l2 = Levers(2.0, 1.0, 0.5, 3.0, 4.0)
    l_max = max(l1, l2)

    @test l_max.withdraw_h == 2.0
    @test l_max.resist_h == 2.0
    @test l_max.resist_p == 0.5
    @test l_max.dike_h == 4.0
    @test l_max.dike_base_h == 4.0

    # max with itself should return same values
    l1_max = max(l1, l1)
    @test l1_max.withdraw_h == l1.withdraw_h
    @test l1_max.resist_h == l1.resist_h
    @test l1_max.resist_p == l1.resist_p
    @test l1_max.dike_h == l1.dike_h
    @test l1_max.dike_base_h == l1.dike_base_h

    # max with zeros should return original
    l_zero = Levers(0, 0, 0, 0, 0)
    l1_max_zero = max(l1, l_zero)
    @test l1_max_zero.withdraw_h == l1.withdraw_h
    @test l1_max_zero.resist_h == l1.resist_h
    @test l1_max_zero.resist_p == l1.resist_p
    @test l1_max_zero.dike_h == l1.dike_h
    @test l1_max_zero.dike_base_h == l1.dike_base_h
end

@testset "Levers is_feasible() Function" begin
    city = CityParameters()

    # All valid configurations
    valid_cases = [
        Levers(0, 0, 0, 0, 0),
        Levers(2.0, 3.0, 0.5, 5.0, 4.0),
        Levers(0, 5.0, 1.0, 0, 0),
        Levers(0, 0, 0, 10.0, 5.0),
    ]

    for levers in valid_cases
        @test is_feasible(levers, city)
    end

    # Invalid configurations (created with validate=false)
    invalid_cases = [
        Levers(10.0, 0, 0, 5.0, 2.0; validate=false),  # W > B
        Levers(0, 0, 1.5, 0, 0; validate=false),       # P > 1
        Levers(0, 0, 0, 20.0, 10.0; validate=false),   # B+D > H_city
        Levers(-1.0, 0, 0, 0, 0; validate=false),      # Negative height
    ]

    for levers in invalid_cases
        @test !is_feasible(levers, city)
    end
end

@testset "Levers Type Conversion" begin
    # Integer inputs should be converted to Float64
    levers_int = Levers(2, 3, 0, 5, 4)
    @test levers_int.withdraw_h isa Float64
    @test levers_int.resist_h isa Float64
    @test levers_int.resist_p isa Float64
    @test levers_int.dike_h isa Float64
    @test levers_int.dike_base_h isa Float64

    # Mixed integer and float inputs
    levers_mixed = Levers(2, 3.5, 0, 5.0, 4)
    @test levers_mixed.withdraw_h == 2.0
    @test levers_mixed.resist_h == 3.5
    @test levers_mixed.dike_h == 5.0
end

@testset "Levers Custom City Height" begin
    # Test with custom city max height
    custom_height = 25.0

    # Valid with custom height
    levers = Levers(5.0, 8.0, 0.5, 10.0, 12.0; city_max_height=custom_height)
    @test levers.dike_base_h + levers.dike_h ≤ custom_height

    # Should fail with default height but pass with custom
    @test_throws AssertionError Levers(0, 0, 0, 15.0, 10.0)
    levers_custom = Levers(0, 0, 0, 15.0, 10.0; city_max_height=custom_height)
    @test levers_custom.dike_h == 15.0
end
