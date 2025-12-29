using ICOW
using Test

@testset "calculate_dike_volume" begin
    @testset "Zero Height Edge Case" begin
        # D=0 still has volume due to D_startup fixed costs
        city = CityParameters()
        @test calculate_dike_volume(city, 0.0) > 0.0

        # Even with D_startup=0 AND D=0, there's a small constant (1/6) from
        # the C++ integer division bug where pow(T, 1/2) = pow(T, 0) = 1
        city_no_startup = CityParameters(D_startup=0.0)
        @test calculate_dike_volume(city_no_startup, 0.0) ≈ 1/6
    end

    @testset "Monotonicity" begin
        # Volume increases with dike height
        city = CityParameters()
        vol1 = calculate_dike_volume(city, 1.0)
        vol5 = calculate_dike_volume(city, 5.0)
        vol10 = calculate_dike_volume(city, 10.0)
        @test vol1 < vol5 < vol10
    end

    @testset "Numerical Stability" begin
        # Should handle a range of realistic values without errors
        city = CityParameters()
        for D in [0.1, 1.0, 5.0, 10.0, 15.0]
            vol = calculate_dike_volume(city, D)
            @test isfinite(vol)
            @test vol >= 0
        end
    end

    @testset "Type Stability" begin
        # Should work with different numeric types
        city32 = CityParameters{Float32}()
        @test calculate_dike_volume(city32, 5.0f0) isa Float32

        city64 = CityParameters{Float64}()
        @test calculate_dike_volume(city64, 5.0) isa Float64
    end

    @testset "Volume Varies with Height" begin
        # Volume should vary with dike height D
        city = CityParameters()
        vol_d3 = calculate_dike_volume(city, 3.0)
        vol_d7 = calculate_dike_volume(city, 7.0)
        @test vol_d3 != vol_d7
    end
end
