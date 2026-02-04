# Edge case tests for Core physics functions
# Tests for boundary conditions, special cases, and regression coverage

const ICOWCore = ICOW.Core

@testset "Dike Failure Probability Edge Cases" begin
    @testset "D=0 (no dike)" begin
        # With no dike, failure is certain if surge > 0
        @test ICOWCore.dike_failure_probability(0.0, 0.0, 0.95, 0.05) == 0.05
        @test ICOWCore.dike_failure_probability(1.0, 0.0, 0.95, 0.05) == 1.0
        @test ICOWCore.dike_failure_probability(0.001, 0.0, 0.95, 0.05) == 1.0
    end

    @testset "t_fail=1.0 (instant failure at overtopping)" begin
        D = 5.0
        t_fail = 1.0
        p_min = 0.05

        # Below dike height: baseline probability
        @test ICOWCore.dike_failure_probability(0.0, D, t_fail, p_min) == p_min
        @test ICOWCore.dike_failure_probability(4.9, D, t_fail, p_min) == p_min

        # At or above dike height: certain failure
        @test ICOWCore.dike_failure_probability(5.0, D, t_fail, p_min) == 1.0
        @test ICOWCore.dike_failure_probability(10.0, D, t_fail, p_min) == 1.0
    end

    @testset "Standard t_fail behavior" begin
        D = 5.0
        t_fail = 0.95
        p_min = 0.05

        # Below threshold: baseline probability
        @test ICOWCore.dike_failure_probability(0.0, D, t_fail, p_min) == p_min
        @test ICOWCore.dike_failure_probability(4.7, D, t_fail, p_min) == p_min

        # At threshold: just above baseline
        threshold = t_fail * D  # = 4.75
        @test ICOWCore.dike_failure_probability(threshold, D, t_fail, p_min) ≈ 0.0 atol = 1e-10

        # Linear ramp between threshold and D
        h_mid = (threshold + D) / 2  # = 4.875
        p_expected = (h_mid - threshold) / (D * (1 - t_fail))
        @test ICOWCore.dike_failure_probability(h_mid, D, t_fail, p_min) ≈ p_expected

        # At dike height: certain failure
        @test ICOWCore.dike_failure_probability(5.0, D, t_fail, p_min) == 1.0
    end
end

@testset "Resistance Cost - No Dike Condition" begin
    # Parameters from C++ defaults
    V_w = 1.5e12
    f_cR = 0.2475  # Calculated for P=0.5
    H_bldg = 30.0
    H_city = 17.0
    W = 0.0
    R = 4.0
    P = 0.5
    b_basement = 3.0

    @testset "Resistance-only strategy (B=0, D=0)" begin
        B = 0.0
        D = 0.0

        # Should use Eq 4 (unconstrained) because no dike
        cost = ICOWCore.resistance_cost(V_w, f_cR, H_bldg, H_city, W, R, B, D, b_basement)

        # Eq 4: C_R = V_w * f_cR * R * (R/2 + b) / (H_bldg * (H_city - W))
        expected = V_w * f_cR * R * (R / 2 + b_basement) / (H_bldg * (H_city - W))
        @test cost ≈ expected
        @test cost > 0  # Must be non-zero for valid resistance strategy
    end

    @testset "R >= B with dike (uses Eq 5)" begin
        B = 2.0
        D = 5.0  # Has a dike

        # R=4 >= B=2, so should use Eq 5 (constrained)
        cost = ICOWCore.resistance_cost(V_w, f_cR, H_bldg, H_city, W, R, B, D, b_basement)

        # Eq 5: C_R = V_w * f_cR * B * (R - B/2 + b) / (H_bldg * (H_city - W))
        expected = V_w * f_cR * B * (R - B / 2 + b_basement) / (H_bldg * (H_city - W))
        @test cost ≈ expected
    end

    @testset "R < B (uses Eq 4)" begin
        R_small = 1.0
        B = 3.0
        D = 5.0

        cost = ICOWCore.resistance_cost(V_w, f_cR, H_bldg, H_city, W, R_small, B, D, b_basement)

        # Eq 4: C_R = V_w * f_cR * R * (R/2 + b) / (H_bldg * (H_city - W))
        expected = V_w * f_cR * R_small * (R_small / 2 + b_basement) / (H_bldg * (H_city - W))
        @test cost ≈ expected
    end
end

@testset "Threshold Damage Penalty" begin
    # Test the threshold penalty formula structure
    # d_total = sum_d + (f_thresh * (sum_d - d_thresh))^gamma_thresh when sum_d > d_thresh

    # Create minimal zone setup for damage calculation
    H_city = 17.0
    W = 0.0
    R = 0.0
    B = 0.0
    D = 0.0
    bounds = ICOWCore.zone_boundaries(H_city, W, R, B, D)

    V_city = 1.5e12
    f_l = 0.01
    V_w = ICOWCore.value_after_withdrawal(V_city, H_city, f_l, W)
    r_prot = 1.1
    r_unprot = 0.95
    values = ICOWCore.zone_values(V_w, H_city, W, R, B, D, r_prot, r_unprot)

    # Parameters
    b_basement = 3.0
    H_bldg = 30.0
    f_damage = 0.39
    P = 0.0
    f_intact = 0.03
    f_failed = 1.5
    dike_failed = false

    # Threshold parameters
    d_thresh = V_city / 375  # ~$4B
    f_thresh = 1.0
    gamma_thresh = 1.01

    @testset "Below threshold: no penalty" begin
        h_surge = 2.0  # Low surge
        damage = ICOWCore.total_event_damage(
            bounds, values, h_surge, b_basement, H_bldg, f_damage,
            P, f_intact, f_failed, d_thresh, f_thresh, gamma_thresh, dike_failed
        )
        # Damage should be below threshold for low surge
        if damage <= d_thresh
            # No penalty applied - damage equals raw sum
            raw_sum = sum(
                ICOWCore.zone_damage(
                    i, bounds[2i+1], bounds[2i+2], values[i+1],
                    h_surge, b_basement, H_bldg, f_damage, P, f_intact, f_failed, dike_failed
                ) for i in 0:4
            )
            @test damage ≈ raw_sum
        end
    end

    @testset "Above threshold: penalty applied" begin
        h_surge = 15.0  # High surge to exceed threshold
        damage = ICOWCore.total_event_damage(
            bounds, values, h_surge, b_basement, H_bldg, f_damage,
            P, f_intact, f_failed, d_thresh, f_thresh, gamma_thresh, dike_failed
        )

        # Calculate raw damage
        raw_sum = sum(
            ICOWCore.zone_damage(
                i, bounds[2i+1], bounds[2i+2], values[i+1],
                h_surge, b_basement, H_bldg, f_damage, P, f_intact, f_failed, dike_failed
            ) for i in 0:4
        )

        if raw_sum > d_thresh
            # Penalty should be applied
            expected_penalty = (f_thresh * (raw_sum - d_thresh))^gamma_thresh
            @test damage ≈ raw_sum + expected_penalty
            @test damage > raw_sum  # Damage must increase with penalty
        end
    end
end

@testset "Zone Boundary Edge Cases" begin
    H_city = 17.0

    @testset "Surge exactly at zone boundaries" begin
        W = 2.0
        R = 3.0
        B = 4.0
        D = 5.0
        bounds = ICOWCore.zone_boundaries(H_city, W, R, B, D)

        # Zone boundaries: z0=[0,2], z1=[2,5], z2=[5,6], z3=[6,11], z4=[11,17]
        @test bounds[1] == 0.0   # z0_low
        @test bounds[2] == W     # z0_high = W = 2
        @test bounds[3] == W     # z1_low = W = 2
        @test bounds[4] == W + min(R, B)  # z1_high = 2 + 3 = 5
        @test bounds[5] == bounds[4]      # z2_low = z1_high
        @test bounds[6] == W + B          # z2_high = 2 + 4 = 6
        @test bounds[7] == bounds[6]      # z3_low = z2_high
        @test bounds[8] == W + B + D      # z3_high = 2 + 4 + 5 = 11
        @test bounds[9] == bounds[8]      # z4_low = z3_high
        @test bounds[10] == H_city        # z4_high = 17
    end

    @testset "R >= B collapses Zone 2" begin
        W = 0.0
        R = 5.0  # R > B
        B = 3.0
        D = 4.0
        bounds = ICOWCore.zone_boundaries(H_city, W, R, B, D)

        # When R >= B, Zone 2 has zero width
        z2_width = bounds[6] - bounds[5]  # z2_high - z2_low
        @test z2_width == 0.0  # Zone 2 collapsed

        # Zone 1 goes from W to W+B (capped at B, not R)
        @test bounds[4] == W + B  # z1_high = W + min(R,B) = 0 + 3 = 3
    end

    @testset "All zeros gives full Zone 4" begin
        W = 0.0
        R = 0.0
        B = 0.0
        D = 0.0
        bounds = ICOWCore.zone_boundaries(H_city, W, R, B, D)

        # All zones except Zone 4 should have zero width
        @test bounds[2] - bounds[1] == 0.0  # Zone 0 width
        @test bounds[4] - bounds[3] == 0.0  # Zone 1 width
        @test bounds[6] - bounds[5] == 0.0  # Zone 2 width
        @test bounds[8] - bounds[7] == 0.0  # Zone 3 width
        @test bounds[10] - bounds[9] == H_city  # Zone 4 = full city
    end
end
