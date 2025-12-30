using ICOW
using Test

@testset "calculate_dike_volume" begin
    city = CityParameters()

    # Zero height: D=0 still has volume due to D_startup
    @test calculate_dike_volume(city, 0.0) > 0.0
    @test calculate_dike_volume(CityParameters(D_startup=0.0), 0.0) ≈ 0.0

    # Monotonicity: volume increases with dike height
    @test calculate_dike_volume(city, 1.0) < calculate_dike_volume(city, 5.0) < calculate_dike_volume(city, 10.0)

    # Numerical stability: finite positive values across range
    for D in [0.1, 5.0, 15.0]
        vol = calculate_dike_volume(city, D)
        @test isfinite(vol) && vol >= 0
    end

    # Type stability
    @test calculate_dike_volume(CityParameters{Float32}(), 5.0f0) isa Float32
    @test calculate_dike_volume(city, 5.0) isa Float64
end
