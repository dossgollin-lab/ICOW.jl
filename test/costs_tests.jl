using ICOW
using Test

@testset "Cost Functions" begin
    # Create default city parameters for testing
    city = CityParameters()

    @testset "calculate_withdrawal_cost" begin
        @testset "Zero Test" begin
            # W=0 should give zero cost
            @test calculate_withdrawal_cost(city, 0.0) == 0.0
        end

        @testset "Monotonicity" begin
            # Increasing W should increase cost
            cost_1 = calculate_withdrawal_cost(city, 1.0)
            cost_5 = calculate_withdrawal_cost(city, 5.0)
            cost_10 = calculate_withdrawal_cost(city, 10.0)
            @test cost_1 < cost_5 < cost_10
        end

        @testset "Type Stability" begin
            # Float32 input should give Float32 output
            city32 = CityParameters{Float32}()
            @test calculate_withdrawal_cost(city32, 1.0f0) isa Float32

            # Float64 input should give Float64 output
            @test calculate_withdrawal_cost(city, 1.0) isa Float64
        end
    end

    @testset "calculate_value_after_withdrawal" begin
        @testset "Zero Test" begin
            # W=0 should give full city value
            @test calculate_value_after_withdrawal(city, 0.0) == city.V_city
        end

        @testset "Monotonicity" begin
            # Increasing W should decrease remaining value
            val_0 = calculate_value_after_withdrawal(city, 0.0)
            val_5 = calculate_value_after_withdrawal(city, 5.0)
            val_10 = calculate_value_after_withdrawal(city, 10.0)
            @test val_0 > val_5 > val_10
        end

        @testset "Type Stability" begin
            city32 = CityParameters{Float32}()
            @test calculate_value_after_withdrawal(city32, 1.0f0) isa Float32
            @test calculate_value_after_withdrawal(city, 1.0) isa Float64
        end
    end

    @testset "calculate_resistance_cost_fraction" begin
        @testset "Zero Test" begin
            # P=0 should give zero fraction
            @test calculate_resistance_cost_fraction(city, 0.0) == 0.0
        end

        @testset "Monotonicity" begin
            # Increasing P should increase cost fraction
            frac_01 = calculate_resistance_cost_fraction(city, 0.1)
            frac_05 = calculate_resistance_cost_fraction(city, 0.5)
            frac_09 = calculate_resistance_cost_fraction(city, 0.9)
            @test frac_01 < frac_05 < frac_09
        end

        @testset "Exponential Growth Near 1.0" begin
            # Cost should grow rapidly as P approaches 1.0
            frac_90 = calculate_resistance_cost_fraction(city, 0.90)
            frac_95 = calculate_resistance_cost_fraction(city, 0.95)
            frac_99 = calculate_resistance_cost_fraction(city, 0.99)

            # Verify exponential growth
            diff_low = frac_95 - frac_90
            diff_high = frac_99 - frac_95
            @test diff_high > diff_low  # Growth accelerates
        end

        @testset "Type Stability" begin
            city32 = CityParameters{Float32}()
            @test calculate_resistance_cost_fraction(city32, 0.5f0) isa Float32
            @test calculate_resistance_cost_fraction(city, 0.5) isa Float64
        end
    end

    @testset "calculate_resistance_cost" begin
        @testset "Zero Test" begin
            # R=0 and P=0 should give zero cost
            levers_zero = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
            @test calculate_resistance_cost(city, levers_zero) == 0.0
        end

        @testset "Monotonicity - R" begin
            # Increasing R should increase cost (with P > 0)
            levers_r1 = Levers(0.0, 1.0, 0.5, 0.0, 5.0)
            levers_r3 = Levers(0.0, 3.0, 0.5, 0.0, 5.0)
            levers_r4 = Levers(0.0, 4.0, 0.5, 0.0, 5.0)

            cost_r1 = calculate_resistance_cost(city, levers_r1)
            cost_r3 = calculate_resistance_cost(city, levers_r3)
            cost_r4 = calculate_resistance_cost(city, levers_r4)

            @test cost_r1 < cost_r3 < cost_r4
        end

        @testset "Monotonicity - P" begin
            # Increasing P should increase cost (with R > 0)
            levers_p01 = Levers(0.0, 2.0, 0.1, 0.0, 5.0)
            levers_p05 = Levers(0.0, 2.0, 0.5, 0.0, 5.0)
            levers_p09 = Levers(0.0, 2.0, 0.9, 0.0, 5.0)

            cost_p01 = calculate_resistance_cost(city, levers_p01)
            cost_p05 = calculate_resistance_cost(city, levers_p05)
            cost_p09 = calculate_resistance_cost(city, levers_p09)

            @test cost_p01 < cost_p05 < cost_p09
        end

        @testset "Constrained vs Unconstrained" begin
            # R < B (unconstrained) vs R >= B (constrained)
            levers_unconstrained = Levers(0.0, 2.0, 0.5, 0.0, 5.0)  # R < B
            levers_constrained = Levers(0.0, 5.0, 0.5, 0.0, 5.0)    # R = B
            levers_dominated = Levers(0.0, 6.0, 0.5, 0.0, 5.0)      # R > B

            cost_unc = calculate_resistance_cost(city, levers_unconstrained)
            cost_con = calculate_resistance_cost(city, levers_constrained)
            cost_dom = calculate_resistance_cost(city, levers_dominated)

            # All should be positive
            @test cost_unc > 0
            @test cost_con > 0
            @test cost_dom > 0

            # Dominated strategy (R > B) should cost more than R = B
            @test cost_dom > cost_con
        end

        @testset "Type Stability" begin
            levers32 = Levers(0.0f0, 2.0f0, 0.5f0, 0.0f0, 5.0f0)
            levers64 = Levers(0.0, 2.0, 0.5, 0.0, 5.0)

            city32 = CityParameters{Float32}()
            @test calculate_resistance_cost(city32, levers32) isa Float32
            @test calculate_resistance_cost(city, levers64) isa Float64
        end
    end

    @testset "calculate_dike_cost" begin
        @testset "Zero When No Dike" begin
            # D=0 means no dike, so cost should be 0
            cost_zero = calculate_dike_cost(city, 0.0, 0.0)
            @test cost_zero == 0.0
        end

        @testset "Positive for Any Dike" begin
            # Even minimal dike (D > 0) has startup costs
            cost_minimal = calculate_dike_cost(city, 0.1, 0.0)
            @test cost_minimal > 0
        end

        @testset "Monotonicity" begin
            # Increasing D should increase cost
            cost_1 = calculate_dike_cost(city, 1.0, 0.0)
            cost_5 = calculate_dike_cost(city, 5.0, 0.0)
            cost_10 = calculate_dike_cost(city, 10.0, 0.0)
            @test cost_1 < cost_5 < cost_10
        end

        @testset "Type Stability" begin
            city32 = CityParameters{Float32}()
            @test calculate_dike_cost(city32, 5.0f0, 0.0f0) isa Float32
            @test calculate_dike_cost(city, 5.0, 0.0) isa Float64
        end
    end

    @testset "calculate_investment_cost" begin
        @testset "Zero Test" begin
            # All levers at 0 should give zero cost (no protection)
            levers_zero = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
            cost_zero = calculate_investment_cost(city, levers_zero)
            @test cost_zero == 0.0
        end

        @testset "Component Sum" begin
            # Verify total equals sum of components
            levers = Levers(2.0, 3.0, 0.5, 4.0, 1.0)

            C_W = calculate_withdrawal_cost(city, levers.W)
            C_R = calculate_resistance_cost(city, levers)
            C_D = calculate_dike_cost(city, levers.D, levers.B)
            C_total = calculate_investment_cost(city, levers)

            @test C_total ≈ C_W + C_R + C_D
        end

        @testset "Monotonicity" begin
            # Increasing any lever should increase total cost
            base_levers = Levers(1.0, 2.0, 0.3, 3.0, 1.0)
            base_cost = calculate_investment_cost(city, base_levers)

            # Increase W
            levers_W = Levers(2.0, 2.0, 0.3, 3.0, 1.0)
            @test calculate_investment_cost(city, levers_W) > base_cost

            # Increase R
            levers_R = Levers(1.0, 3.0, 0.3, 3.0, 1.0)
            @test calculate_investment_cost(city, levers_R) > base_cost

            # Increase P
            levers_P = Levers(1.0, 2.0, 0.5, 3.0, 1.0)
            @test calculate_investment_cost(city, levers_P) > base_cost

            # Increase D
            levers_D = Levers(1.0, 2.0, 0.3, 5.0, 1.0)
            @test calculate_investment_cost(city, levers_D) > base_cost

            # Increase B (affects resistance cost when R >= B)
            levers_B = Levers(1.0, 2.0, 0.3, 3.0, 2.0)
            @test calculate_investment_cost(city, levers_B) > base_cost
        end

        @testset "Type Stability" begin
            levers32 = Levers(1.0f0, 2.0f0, 0.5f0, 3.0f0, 1.0f0)
            levers64 = Levers(1.0, 2.0, 0.5, 3.0, 1.0)

            city32 = CityParameters{Float32}()
            @test calculate_investment_cost(city32, levers32) isa Float32
            @test calculate_investment_cost(city, levers64) isa Float64
        end
    end
end

@testset "Surge and Failure Functions" begin
    city = CityParameters()

    @testset "calculate_effective_surge" begin
        @testset "Below Seawall" begin
            # Surge below seawall should give zero effective surge
            @test calculate_effective_surge(0.5, city) == 0.0
            @test calculate_effective_surge(city.H_seawall, city) == 0.0
        end

        @testset "Above Seawall" begin
            # Surge above seawall should apply runup and subtract seawall
            h_raw = 3.0
            h_eff = calculate_effective_surge(h_raw, city)

            # Should equal: h_raw * f_runup - H_seawall
            expected = h_raw * city.f_runup - city.H_seawall
            @test h_eff ≈ expected
            @test h_eff > 0
        end

        @testset "Monotonicity" begin
            # Increasing raw surge should increase effective surge
            h_eff_3 = calculate_effective_surge(3.0, city)
            h_eff_5 = calculate_effective_surge(5.0, city)
            h_eff_8 = calculate_effective_surge(8.0, city)
            @test h_eff_3 < h_eff_5 < h_eff_8
        end

        @testset "Type Stability" begin
            city32 = CityParameters{Float32}()
            @test calculate_effective_surge(3.0f0, city32) isa Float32
            @test calculate_effective_surge(3.0, city) isa Float64
        end
    end

    @testset "calculate_dike_failure_probability" begin
        D = 5.0  # Dike height
        threshold = city.t_fail * D  # 0.95 * 5.0 = 4.75

        @testset "Zero Surge" begin
            # Zero surge should give minimum probability
            @test calculate_dike_failure_probability(0.0, D, city) == city.p_min
        end

        @testset "Below Threshold" begin
            # Surge below threshold should give p_min
            h_surge = threshold * 0.5
            @test calculate_dike_failure_probability(h_surge, D, city) == city.p_min
        end

        @testset "Linear Region" begin
            # Surge in linear region should give intermediate probability
            h_surge = (threshold + D) / 2  # Midpoint of linear region
            p_fail = calculate_dike_failure_probability(h_surge, D, city)

            @test p_fail > city.p_min
            @test p_fail < 1.0

            # Verify linear relationship
            # p_fail = (h_surge - threshold) / (D * (1 - t_fail))
            expected = (h_surge - threshold) / (D * (1.0 - city.t_fail))
            @test p_fail ≈ expected
        end

        @testset "Above Dike" begin
            # Surge above dike height should give certain failure
            h_surge = D + 1.0
            @test calculate_dike_failure_probability(h_surge, D, city) == 1.0
        end

        @testset "Exactly at Dike Height" begin
            # Surge exactly at D should give probability 1.0
            @test calculate_dike_failure_probability(D, D, city) == 1.0
        end

        @testset "No Dike (D=0)" begin
            # With no dike, any positive surge causes certain failure
            @test calculate_dike_failure_probability(0.0, 0.0, city) == city.p_min
            @test calculate_dike_failure_probability(0.1, 0.0, city) == 1.0
            @test calculate_dike_failure_probability(5.0, 0.0, city) == 1.0
        end

        @testset "Monotonicity" begin
            # Increasing surge should increase failure probability
            p1 = calculate_dike_failure_probability(2.0, D, city)
            p2 = calculate_dike_failure_probability(4.0, D, city)
            p3 = calculate_dike_failure_probability(6.0, D, city)
            @test p1 <= p2 <= p3
        end

        @testset "Type Stability" begin
            city32 = CityParameters{Float32}()
            @test calculate_dike_failure_probability(3.0f0, 5.0f0, city32) isa Float32
            @test calculate_dike_failure_probability(3.0, 5.0, city) isa Float64
        end
    end
end
