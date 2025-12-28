using ICOW
using Test

@testset "CityParameters" begin
    @testset "Default Construction" begin
        city = CityParameters()

        # Geometry defaults from equations.md (C++ values)
        @test city.V_city == 1.5e12
        @test city.H_bldg == 30.0
        @test city.H_city == 17.0
        @test city.D_city == 2000.0
        @test city.W_city == 43000.0
        @test city.H_seawall == 1.75

        # Dike defaults
        @test city.D_startup == 2.0
        @test city.w_d == 3.0
        @test city.s_dike == 0.5
        @test city.c_d == 10.0

        # Zones defaults
        @test city.r_prot == 1.1
        @test city.r_unprot == 0.95

        # Withdrawal defaults
        @test city.f_w == 1.0
        @test city.f_l == 0.01

        # Resistance defaults
        @test city.f_adj == 1.25
        @test city.f_lin == 0.35
        @test city.f_exp == 0.115
        @test city.t_exp == 0.4
        @test city.b_basement == 3.0

        # Damage defaults
        @test city.f_damage == 0.39
        @test city.f_intact == 0.03
        @test city.f_failed == 1.5
        @test city.t_fail == 0.95
        @test city.p_min == 0.05
        @test city.f_runup == 1.1

        # Threshold defaults
        @test city.d_thresh == city.V_city / 375
        @test city.f_thresh == 1.0
        @test city.gamma_thresh == 1.01
    end

    @testset "Parameterized Construction" begin
        city32 = CityParameters{Float32}()
        @test city32.V_city isa Float32
        @test city32.H_city isa Float32
        @test city32.d_thresh isa Float32

        city64 = CityParameters{Float64}()
        @test city64.V_city isa Float64
    end

    @testset "Custom Values" begin
        city = CityParameters(V_city=2.0e12, H_city=20.0, f_damage=0.5)
        @test city.V_city == 2.0e12
        @test city.H_city == 20.0
        @test city.f_damage == 0.5
        # Other values should remain default
        @test city.H_bldg == 30.0
    end

    @testset "d_thresh Default Computation" begin
        # Default d_thresh should be V_city / 375
        city = CityParameters()
        @test city.d_thresh == city.V_city / 375

        # Custom d_thresh should override
        city2 = CityParameters(d_thresh=1.0e9)
        @test city2.d_thresh == 1.0e9

        # d_thresh should scale with custom V_city
        city3 = CityParameters(V_city=3.0e12)
        @test city3.d_thresh == 3.0e12 / 375

        # Type promotion: d_thresh should match struct type
        city32 = CityParameters{Float32}(V_city=1.5e12)
        @test city32.d_thresh isa Float32
    end
end

@testset "validate_parameters" begin
    @testset "Valid Parameters" begin
        city = CityParameters()
        @test validate_parameters(city) === nothing
    end

    @testset "Positive Values Required" begin
        # V_city > 0; city must have positive value
        @test_throws AssertionError validate_parameters(CityParameters(V_city=-1.0))
        @test_throws AssertionError validate_parameters(CityParameters(V_city=0.0))

        # H_bldg > 0; buildings must have positive height
        @test_throws AssertionError validate_parameters(CityParameters(H_bldg=0.0))

        # H_city > 0; city must have positive elevation
        @test_throws AssertionError validate_parameters(CityParameters(H_city=0.0))

        # D_city > 0; city must have positive depth
        @test_throws AssertionError validate_parameters(CityParameters(D_city=0.0))

        # W_city > 0; city must have positive coastline
        @test_throws AssertionError validate_parameters(CityParameters(W_city=0.0))

        # s_dike > 0; slope must be positive for geometry
        @test_throws AssertionError validate_parameters(CityParameters(s_dike=0.0))
    end

    @testset "Non-Negative Values" begin
        # H_seawall >= 0; can be zero (no seawall)
        @test validate_parameters(CityParameters(H_seawall=0.0)) === nothing
        @test_throws AssertionError validate_parameters(CityParameters(H_seawall=-1.0))

        # D_startup >= 0
        @test validate_parameters(CityParameters(D_startup=0.0)) === nothing
        @test_throws AssertionError validate_parameters(CityParameters(D_startup=-1.0))

        # w_d >= 0
        @test validate_parameters(CityParameters(w_d=0.0)) === nothing
        @test_throws AssertionError validate_parameters(CityParameters(w_d=-1.0))

        # c_d >= 0
        @test validate_parameters(CityParameters(c_d=0.0)) === nothing
        @test_throws AssertionError validate_parameters(CityParameters(c_d=-1.0))

        # b_basement >= 0
        @test validate_parameters(CityParameters(b_basement=0.0)) === nothing
        @test_throws AssertionError validate_parameters(CityParameters(b_basement=-1.0))

        # d_thresh >= 0
        @test validate_parameters(CityParameters(d_thresh=0.0)) === nothing
        @test_throws AssertionError validate_parameters(CityParameters(d_thresh=-1.0))
    end

    @testset "Fractions in [0, 1]" begin
        # f_l in [0, 1]; loss fraction is a fraction
        @test_throws AssertionError validate_parameters(CityParameters(f_l=-0.1))
        @test_throws AssertionError validate_parameters(CityParameters(f_l=1.5))
        @test validate_parameters(CityParameters(f_l=0.0)) === nothing
        @test validate_parameters(CityParameters(f_l=1.0)) === nothing

        # f_damage in [0, 1]
        @test_throws AssertionError validate_parameters(CityParameters(f_damage=-0.1))
        @test_throws AssertionError validate_parameters(CityParameters(f_damage=1.5))

        # t_fail in [0, 1]
        @test_throws AssertionError validate_parameters(CityParameters(t_fail=-0.1))
        @test_throws AssertionError validate_parameters(CityParameters(t_fail=1.5))

        # p_min in [0, 1]
        @test_throws AssertionError validate_parameters(CityParameters(p_min=-0.1))
        @test_throws AssertionError validate_parameters(CityParameters(p_min=1.5))

        # t_exp in [0, 1]
        @test_throws AssertionError validate_parameters(CityParameters(t_exp=-0.1))
        @test_throws AssertionError validate_parameters(CityParameters(t_exp=1.5))
    end

    @testset "Positive Multipliers" begin
        # f_w > 0; must be positive
        @test_throws AssertionError validate_parameters(CityParameters(f_w=0.0))
        @test_throws AssertionError validate_parameters(CityParameters(f_w=-1.0))

        # f_adj > 0
        @test_throws AssertionError validate_parameters(CityParameters(f_adj=0.0))
        @test_throws AssertionError validate_parameters(CityParameters(f_adj=-1.0))

        # r_prot > 0
        @test_throws AssertionError validate_parameters(CityParameters(r_prot=0.0))
        @test_throws AssertionError validate_parameters(CityParameters(r_prot=-1.0))

        # r_unprot > 0
        @test_throws AssertionError validate_parameters(CityParameters(r_unprot=0.0))
        @test_throws AssertionError validate_parameters(CityParameters(r_unprot=-1.0))
    end

    @testset "Runup Factor" begin
        # f_runup >= 1.0; amplification should not attenuate
        @test_throws AssertionError validate_parameters(CityParameters(f_runup=0.9))
        @test validate_parameters(CityParameters(f_runup=1.0)) === nothing
        @test validate_parameters(CityParameters(f_runup=1.5)) === nothing
    end
end

@testset "city_slope" begin
    # Uses H_city / D_city per equations.md (NOT buggy C++ formula)
    city = CityParameters(H_city=17.0, D_city=2000.0)
    @test city_slope(city) == 17.0 / 2000.0

    # Different values
    city2 = CityParameters(H_city=10.0, D_city=1000.0)
    @test city_slope(city2) == 10.0 / 1000.0
    @test city_slope(city2) == 0.01

    # Type stability
    city32 = CityParameters{Float32}(H_city=17.0f0, D_city=2000.0f0)
    @test city_slope(city32) isa Float32
end

@testset "Type Stability" begin
    # Type stability is critical for performance in the optimization loop
    city = CityParameters()
    @test (@inferred city_slope(city)) isa Float64
end
