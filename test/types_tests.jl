using ICOW
using Test

@testset "Levers" begin
    @testset "Valid Construction" begin
        # Zero levers (no protection)
        levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
        @test levers.W == 0.0
        @test levers.R == 0.0
        @test levers.P == 0.0
        @test levers.D == 0.0
        @test levers.B == 0.0

        # Moderate protection
        levers2 = Levers(5.0, 2.0, 0.5, 5.0, 2.0)
        @test levers2.W == 5.0
        @test levers2.R == 2.0
        @test levers2.P == 0.5
        @test levers2.D == 5.0
        @test levers2.B == 2.0
    end

    @testset "Type Parameterization" begin
        levers32 = Levers{Float32}(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
        @test levers32.W isa Float32
        @test levers32.R isa Float32
        @test levers32.P isa Float32
        @test levers32.D isa Float32
        @test levers32.B isa Float32

        levers64 = Levers{Float64}(1.0, 2.0, 0.5, 3.0, 1.0)
        @test levers64.W isa Float64
    end

    @testset "Type Promotion" begin
        # Mixed Int and Float should promote to Float64
        levers = Levers(1, 2, 0.5, 3, 1)
        @test levers.W isa Float64
        @test levers.R isa Float64
        @test levers.P isa Float64
        @test levers.D isa Float64
        @test levers.B isa Float64
    end

    @testset "Basic Constraint Validation" begin
        # W >= 0; withdrawal cannot be negative
        @test_throws AssertionError Levers(-1.0, 0.0, 0.0, 0.0, 0.0)

        # R >= 0; resistance height cannot be negative
        @test_throws AssertionError Levers(0.0, -1.0, 0.0, 0.0, 0.0)

        # P >= 0; resistance percentage cannot be negative
        @test_throws AssertionError Levers(0.0, 0.0, -0.1, 0.0, 0.0)

        # P < 1.0; P=1.0 causes division by zero in Equation 3
        @test_throws AssertionError Levers(0.0, 0.0, 1.0, 0.0, 0.0)
        @test_throws AssertionError Levers(0.0, 0.0, 1.5, 0.0, 0.0)

        # D >= 0; dike height cannot be negative
        @test_throws AssertionError Levers(0.0, 0.0, 0.0, -1.0, 0.0)

        # B >= 0; dike base cannot be negative
        @test_throws AssertionError Levers(0.0, 0.0, 0.0, 0.0, -1.0)
    end

    @testset "Boundary Values" begin
        # P = 0 is valid (no resistance)
        levers_p0 = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
        @test levers_p0.P == 0.0

        # P = 0.999 is valid (high but not full resistance)
        levers_p999 = Levers(0.0, 0.0, 0.999, 0.0, 0.0)
        @test levers_p999.P == 0.999

        # P = 0.9999 should still be valid
        levers_p9999 = Levers(0.0, 0.0, 0.9999, 0.0, 0.0)
        @test levers_p9999.P == 0.9999

        # P = 1.0 must throw (division by zero)
        @test_throws AssertionError Levers(0.0, 0.0, 1.0, 0.0, 0.0)

        # W = 0 is valid (no withdrawal)
        @test Levers(0.0, 0.0, 0.0, 0.0, 0.0).W == 0.0

        # Large positive values are valid
        @test Levers(100.0, 100.0, 0.99, 100.0, 100.0).W == 100.0
    end
end

@testset "is_feasible" begin
    city = CityParameters()  # H_city = 17.0 by default

    @testset "Feasible Configurations" begin
        # Zero levers always feasible
        @test is_feasible(Levers(0.0, 0.0, 0.0, 0.0, 0.0), city) == true

        # Moderate protection
        @test is_feasible(Levers(5.0, 2.0, 0.5, 5.0, 2.0), city) == true

        # W = H_city (full withdrawal, edge case)
        @test is_feasible(Levers(17.0, 0.0, 0.0, 0.0, 0.0), city) == true

        # W + B + D = H_city (dike at city peak, edge case)
        @test is_feasible(Levers(5.0, 0.0, 0.0, 6.0, 6.0), city) == true
    end

    @testset "Infeasible Configurations" begin
        # W > H_city; cannot withdraw above city peak
        @test is_feasible(Levers(18.0, 0.0, 0.0, 0.0, 0.0), city) == false

        # W + B + D > H_city; dike exceeds city elevation
        @test is_feasible(Levers(10.0, 0.0, 0.0, 5.0, 5.0), city) == false

        # Just over the limit
        @test is_feasible(Levers(5.0, 0.0, 0.0, 6.1, 6.0), city) == false
    end

    @testset "Custom City Parameters" begin
        # Taller city allows higher levers
        tall_city = CityParameters(H_city=25.0)
        @test is_feasible(Levers(20.0, 0.0, 0.0, 0.0, 0.0), tall_city) == true
        @test is_feasible(Levers(26.0, 0.0, 0.0, 0.0, 0.0), tall_city) == false
    end
end

@testset "Levers max (irreversibility)" begin
    @testset "Element-wise Maximum" begin
        a = Levers(1.0, 2.0, 0.3, 4.0, 1.0)
        b = Levers(2.0, 1.0, 0.5, 3.0, 2.0)

        result = max(a, b)

        @test result.W == 2.0  # max(1.0, 2.0)
        @test result.R == 2.0  # max(2.0, 1.0)
        @test result.P == 0.5  # max(0.3, 0.5)
        @test result.D == 4.0  # max(4.0, 3.0)
        @test result.B == 2.0  # max(1.0, 2.0)
    end

    @testset "Identical Levers" begin
        a = Levers(5.0, 3.0, 0.6, 4.0, 2.0)
        result = max(a, a)

        @test result.W == a.W
        @test result.R == a.R
        @test result.P == a.P
        @test result.D == a.D
        @test result.B == a.B
    end

    @testset "One Dominates" begin
        small = Levers(1.0, 1.0, 0.1, 1.0, 1.0)
        large = Levers(5.0, 5.0, 0.5, 5.0, 5.0)

        result = max(small, large)

        @test result.W == large.W
        @test result.R == large.R
        @test result.P == large.P
        @test result.D == large.D
        @test result.B == large.B
    end

    @testset "Type Preservation" begin
        a = Levers{Float32}(1.0f0, 2.0f0, 0.3f0, 4.0f0, 1.0f0)
        b = Levers{Float32}(2.0f0, 1.0f0, 0.5f0, 3.0f0, 2.0f0)

        result = max(a, b)

        @test result.W isa Float32
        @test result.R isa Float32
    end
end
