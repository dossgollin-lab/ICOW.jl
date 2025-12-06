using Test

@testset "CityParameters Construction" begin
    # Test default construction
    city = CityParameters()
    @test city.total_value == 1.5e12
    @test city.city_max_height == 17.0
    @test city.n_years == 50
    @test city.discount_rate == 0.04

    # Test custom construction with keyword arguments
    city_custom = CityParameters(
        total_value = 2.0e12,
        discount_rate = 0.05,
        n_years = 100
    )
    @test city_custom.total_value == 2.0e12
    @test city_custom.discount_rate == 0.05
    @test city_custom.n_years == 100
    @test city_custom.city_max_height == 17.0  # Still uses default
end

@testset "CityParameters Validation" begin
    # Valid default parameters
    city = CityParameters()
    @test validate_parameters(city) == true

    # total_value > 0; negative values are physically meaningless
    @test_throws AssertionError validate_parameters(
        CityParameters(total_value = -1000.0)
    )

    # city_max_height > seawall_height; the city must extend above the seawall
    @test_throws AssertionError validate_parameters(
        CityParameters(city_max_height = 1.0, seawall_height = 2.0)
    )

    # 0 < discount_rate < 1; rates outside this range are economically invalid
    @test_throws AssertionError validate_parameters(
        CityParameters(discount_rate = 0.0)
    )

    @test_throws AssertionError validate_parameters(
        CityParameters(discount_rate = 1.5)
    )

    # city_slope must equal city_max_height / city_depth for geometric consistency
    @test_throws AssertionError validate_parameters(
        CityParameters(city_slope = 0.01, city_max_height = 17.0, city_depth = 2000.0)
    )

    # 0 ≤ resistance_threshold ≤ 1; threshold is a percentage/fraction
    @test_throws AssertionError validate_parameters(
        CityParameters(resistance_threshold = 1.5)
    )

    @test_throws AssertionError validate_parameters(
        CityParameters(resistance_threshold = -0.1)
    )

    # n_years > 0; must simulate at least one year
    @test_throws AssertionError validate_parameters(
        CityParameters(n_years = 0)
    )

    @test_throws AssertionError validate_parameters(
        CityParameters(n_years = -10)
    )
end

@testset "CityParameters Slope Consistency" begin
    # Default parameters should have consistent slope
    city = CityParameters()
    @test city.city_slope ≈ city.city_max_height / city.city_depth

    # Custom parameters with consistent slope
    city_custom = CityParameters(
        city_max_height = 20.0,
        city_depth = 2500.0,
        city_slope = 20.0 / 2500.0
    )
    @test validate_parameters(city_custom) == true
end

@testset "CityParameters Physical Ranges" begin
    city = CityParameters()

    # Check that geometry parameters are positive
    @test city.total_value > 0
    @test city.building_height > 0
    @test city.city_max_height > 0
    @test city.city_depth > 0
    @test city.city_length > 0
    @test city.seawall_height > 0

    # Check that cost factors are non-negative
    @test city.dike_cost_per_m3 ≥ 0
    @test city.withdrawal_factor ≥ 0
    @test city.resistance_linear_factor ≥ 0
    @test city.resistance_exp_factor ≥ 0

    # Check that fractions are in [0, 1]
    @test 0 ≤ city.withdrawal_fraction ≤ 1
    @test 0 ≤ city.resistance_threshold ≤ 1
    @test 0 ≤ city.damage_fraction ≤ 1
    @test 0 ≤ city.dike_failure_threshold ≤ 1

    # Check that discount rate is in valid range
    @test 0 < city.discount_rate < 1
end
