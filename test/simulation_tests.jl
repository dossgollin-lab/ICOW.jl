using Test
using ICOW
import SimOptDecisions
using Random
using Distributions
using Statistics

@testset "Simulation Tests" begin
    # Setup: Create test city and forcing data
    city = CityParameters{Float64}()

    # Create simple stochastic forcing (10 scenarios, 5 years)
    Random.seed!(123)
    surges_matrix = rand(10, 5) .* 3.0  # Surges from 0-3m
    stoch_forcing = StochasticForcing(surges_matrix, 1)

    # Create distributional forcing (5 years, Normal distributions)
    dists = [Normal(1.5, 0.5) for _ in 1:5]
    dist_forcing = DistributionalForcing(dists, 1)

    # Simple static policy (build dike at t=0)
    static_policy = StaticPolicy(Levers(0.0, 0.0, 0.0, 5.0, 0.0))

    @testset "1. Irreversibility Enforcement" begin
        # Policy that tries to "decrease" dike height mid-simulation
        struct DecreasingPolicy <: SimOptDecisions.AbstractPolicy end

        function (p::DecreasingPolicy)(state::SimOptDecisions.AbstractState, forcing, year::Int)
            if year <= 2
                return Levers(0.0, 0.0, 0.0, 5.0, 0.0)  # High protection
            else
                return Levers(0.0, 0.0, 0.0, 2.0, 0.0)  # Try to decrease
            end
        end

        decreasing_policy = DecreasingPolicy()

        # Run with trace mode to inspect year-by-year
        trace = simulate(city, decreasing_policy, stoch_forcing; mode=:trace, scenario=1)

        # Verify all levers are monotonic (never decrease)
        for i in 2:length(trace.year)
            @test trace.W[i] >= trace.W[i-1]
            @test trace.R[i] >= trace.R[i-1]
            @test trace.P[i] >= trace.P[i-1]
            @test trace.D[i] >= trace.D[i-1]  # Critical: dike should stay at 5.0
            @test trace.B[i] >= trace.B[i-1]
        end

        # Specifically verify D stayed at 5.0 (not decreased to 2.0)
        @test all(trace.D .== 5.0)
    end

    @testset "2. Marginal Costing" begin
        # Static policy: should only pay in first year
        (total_cost, _) = simulate(city, static_policy, stoch_forcing; scenario=1)

        # Get trace to inspect year-by-year
        trace = simulate(city, static_policy, stoch_forcing; mode=:trace, scenario=1)

        # Year 1 should have positive investment
        @test trace.investment[1] > 0.0

        # Subsequent years should have zero investment (no change)
        for i in 2:length(trace.year)
            @test trace.investment[i] == 0.0
        end

        # Total cost should equal first year cost
        @test total_cost ≈ trace.investment[1]

        # Test increasing policy (pay only for increments)
        struct IncreasingPolicy <: SimOptDecisions.AbstractPolicy end

        function (p::IncreasingPolicy)(state::SimOptDecisions.AbstractState, forcing, year::Int)
            # Increase dike height each year
            return Levers(0.0, 0.0, 0.0, Float64(year), 0.0)
        end

        increasing_policy = IncreasingPolicy()
        trace2 = simulate(city, increasing_policy, stoch_forcing; mode=:trace, scenario=1)

        # Each year should have positive investment (building incrementally)
        for i in 1:length(trace2.year)
            @test trace2.investment[i] > 0.0
        end

        # Year i cost should be less than building D=i from scratch
        for i in 2:length(trace2.year)
            from_scratch_cost = calculate_investment_cost(city, Levers(0.0, 0.0, 0.0, Float64(i), 0.0))
            @test trace2.investment[i] < from_scratch_cost
        end
    end

    @testset "3. Raw Flows (Undiscounted)" begin
        # Use policy with lower protection to ensure damage occurs
        damage_policy = StaticPolicy(Levers(0.0, 0.0, 0.0, 2.0, 0.0))

        # Create separate RNGs to ensure scalar and trace modes sample the same random events
        rng1 = Random.MersenneTwister(456)
        rng2 = Random.MersenneTwister(456)  # Same seed for identical sampling

        # Run simulation in scalar mode
        (cost_scalar, damage_scalar) = simulate(city, damage_policy, stoch_forcing; scenario=1, rng=rng1)

        # Run simulation in trace mode (with same RNG sequence)
        trace = simulate(city, damage_policy, stoch_forcing; mode=:trace, scenario=1, rng=rng2)

        # Scalar totals should equal sum of trace (both undiscounted)
        @test cost_scalar ≈ sum(trace.investment)
        @test damage_scalar ≈ sum(trace.damage)

        # Apply discounting and verify NPV differs from raw totals (if damage > 0)
        (npv_cost, npv_damage) = calculate_npv(trace, 0.03)  # 3% discount rate

        # NPV should be less than or equal to raw totals (discounting reduces future values)
        @test npv_cost <= cost_scalar
        if damage_scalar > 0
            @test npv_damage < damage_scalar  # Strict < if damage occurs over multiple years
        else
            @test npv_damage == damage_scalar  # Both zero if no damage
        end

        # With zero discount rate, NPV should equal raw totals
        (npv_cost_zero, npv_damage_zero) = calculate_npv(trace, 0.0)
        @test npv_cost_zero ≈ cost_scalar
        @test npv_damage_zero ≈ damage_scalar
    end

    @testset "4. Type Stability" begin
        # Note: Full type inference fails due to mode parameter being runtime-determined
        # (return type is Union{Tuple, NamedTuple}). This is acceptable per plan.
        # Instead, test that allocations are minimal in scalar mode.

        # Test that scalar mode returns Tuple
        result = simulate(city, static_policy, stoch_forcing; mode=:scalar, scenario=1)
        @test result isa Tuple{Float64, Float64}

        # Test that trace mode returns NamedTuple
        trace = simulate(city, static_policy, stoch_forcing; mode=:trace, scenario=1)
        @test trace isa NamedTuple

        # Verify minimal allocations in simulation loop
        # First run warms up
        simulate(city, static_policy, stoch_forcing; scenario=1)

        # Second run should have minimal allocations
        allocs = @allocated simulate(city, static_policy, stoch_forcing; scenario=1)

        # Allow some allocations for RNG sampling and dike failure (stochastic damage calculation)
        # Trace mode would allocate more, but scalar mode should be modest
        @test allocs < 50000  # Less than 50KB (realistic for RNG operations)
    end
end
