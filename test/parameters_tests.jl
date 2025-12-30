using ICOW
using Test

@testset "CityParameters" begin
    @testset "Default Construction" begin
        city = CityParameters()

        # Key defaults from equations.md
        @test city.V_city == 1.5e12
        @test city.H_city == 17.0
        @test city.D_city == 2000.0
        @test city.W_city == 43000.0
        @test city.d_thresh == city.V_city / 375
    end

    @testset "Type Parameterization" begin
        @test CityParameters{Float32}().V_city isa Float32
        @test CityParameters{Float64}().V_city isa Float64
    end

    @testset "Custom Values" begin
        city = CityParameters(V_city=2.0e12, H_city=20.0)
        @test city.V_city == 2.0e12
        @test city.H_city == 20.0
        @test city.H_bldg == 30.0  # Unchanged default
    end
end

@testset "validate_parameters" begin
    @test validate_parameters(CityParameters()) === nothing

    # Positive values required
    @test_throws AssertionError validate_parameters(CityParameters(V_city=0.0))
    @test_throws AssertionError validate_parameters(CityParameters(H_city=0.0))

    # Non-negative allowed
    @test validate_parameters(CityParameters(H_seawall=0.0)) === nothing
    @test_throws AssertionError validate_parameters(CityParameters(H_seawall=-1.0))

    # Fractions in [0, 1]
    @test_throws AssertionError validate_parameters(CityParameters(f_damage=1.5))
    @test_throws AssertionError validate_parameters(CityParameters(t_fail=-0.1))

    # f_runup >= 1.0
    @test_throws AssertionError validate_parameters(CityParameters(f_runup=0.9))
end

@testset "city_slope" begin
    city = CityParameters(H_city=17.0, D_city=2000.0)
    @test city_slope(city) == 17.0 / 2000.0
    @test (@inferred city_slope(city)) isa Float64
end
