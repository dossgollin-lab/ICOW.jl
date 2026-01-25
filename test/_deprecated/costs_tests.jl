using ICOW
using Test

@testset "Cost Functions" begin
    city = CityParameters()

    @testset "calculate_withdrawal_cost" begin
        @test calculate_withdrawal_cost(city, 0.0) == 0.0
        @test calculate_withdrawal_cost(city, 1.0) < calculate_withdrawal_cost(city, 5.0)
    end

    @testset "calculate_value_after_withdrawal" begin
        @test calculate_value_after_withdrawal(city, 0.0) == city.V_city
        @test calculate_value_after_withdrawal(city, 0.0) > calculate_value_after_withdrawal(city, 5.0)
    end

    @testset "calculate_resistance_cost_fraction" begin
        @test calculate_resistance_cost_fraction(city, 0.0) == 0.0
        @test calculate_resistance_cost_fraction(city, 0.1) < calculate_resistance_cost_fraction(city, 0.9)
    end

    @testset "calculate_resistance_cost" begin
        @test calculate_resistance_cost(city, FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0)) == 0.0

        # Monotonicity in R and P (keep R < B to avoid warnings)
        @test calculate_resistance_cost(city, FloodDefenses(0.0, 1.0, 0.5, 0.0, 5.0)) <
              calculate_resistance_cost(city, FloodDefenses(0.0, 3.0, 0.5, 0.0, 5.0))
        @test calculate_resistance_cost(city, FloodDefenses(0.0, 2.0, 0.1, 0.0, 5.0)) <
              calculate_resistance_cost(city, FloodDefenses(0.0, 2.0, 0.9, 0.0, 5.0))

        # R > B warns about dominated strategy
        @test_warn "R > B is a dominated strategy" calculate_resistance_cost(city, FloodDefenses(0.0, 6.0, 0.5, 0.0, 5.0))
    end

    @testset "calculate_dike_cost" begin
        @test calculate_dike_cost(city, 0.0) == 0.0
        @test calculate_dike_cost(city, 0.1) > 0
        @test calculate_dike_cost(city, 1.0) < calculate_dike_cost(city, 5.0)
    end

    @testset "calculate_investment_cost" begin
        # Zero levers = zero cost
        @test calculate_investment_cost(city, FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0)) == 0.0

        # Component sum equals total
        levers = FloodDefenses(2.0, 3.0, 0.5, 4.0, 1.0)
        C_W = calculate_withdrawal_cost(city, levers.W)
        C_R = calculate_resistance_cost(city, levers)
        C_D = calculate_dike_cost(city, levers.D)
        @test calculate_investment_cost(city, levers) ≈ C_W + C_R + C_D
    end

    @testset "Type stability" begin
        city32 = CityParameters{Float32}()
        levers32 = FloodDefenses(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
        @test calculate_investment_cost(city32, levers32) isa Float32
        @test calculate_investment_cost(city, FloodDefenses(1.0, 2.0, 0.5, 3.0, 1.0)) isa Float64
    end
end

@testset "Surge and Failure Functions" begin
    city = CityParameters()

    @testset "calculate_effective_surge" begin
        # Below seawall = zero effective surge
        @test calculate_effective_surge(0.5, city) == 0.0
        @test calculate_effective_surge(city.H_seawall, city) == 0.0

        # Above seawall = h_raw * f_runup - H_seawall
        h_raw = 3.0
        @test calculate_effective_surge(h_raw, city) ≈ h_raw * city.f_runup - city.H_seawall

        # Monotonicity
        @test calculate_effective_surge(3.0, city) < calculate_effective_surge(5.0, city)
    end

    @testset "calculate_dike_failure_probability" begin
        D = 5.0
        threshold = city.t_fail * D  # 0.95 * 5.0 = 4.75

        # Zero surge = p_min
        @test calculate_dike_failure_probability(0.0, D, city) == city.p_min

        # Below threshold = p_min
        @test calculate_dike_failure_probability(threshold * 0.5, D, city) == city.p_min

        # At dike height = certain failure
        @test calculate_dike_failure_probability(D, D, city) == 1.0

        # Above dike = certain failure
        @test calculate_dike_failure_probability(D + 1.0, D, city) == 1.0

        # No dike (D=0): any positive surge = failure
        @test calculate_dike_failure_probability(0.1, 0.0, city) == 1.0

        # Monotonicity in linear region
        @test calculate_dike_failure_probability(4.8, D, city) < calculate_dike_failure_probability(4.9, D, city)
    end
end
