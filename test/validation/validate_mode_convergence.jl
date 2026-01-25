# Mode Convergence Validation Script
# Compares EAD mode against stochastic mode for static policies
# Demonstrates Law of Large Numbers convergence

using ICOW
using Random
using Distributions
using Statistics
using Printf

println("="^70)
println("MODE CONVERGENCE VALIDATION")
println("="^70)
println()

# Setup: Create test city
println("Setting up test city with default parameters...")
city = CityParameters{Float64}()
println("  City height: $(city.H_city) m")
println("  City value: \$$(city.V_city / 1e6) million")
println()

# Test scenarios with different protection levels
test_policies = [
    ("No protection", StaticPolicy(FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0))),
    ("Low dike (3m)", StaticPolicy(FloodDefenses(0.0, 0.0, 0.0, 3.0, 0.0))),
    ("High dike (5m)", StaticPolicy(FloodDefenses(0.0, 0.0, 0.0, 5.0, 0.0))),
    ("Mixed strategy", StaticPolicy(FloodDefenses(1.0, 2.0, 0.3, 4.0, 1.0))),
]

# Simulation parameters
n_years = 50
n_scenarios = 2000  # For convergence analysis
test_scenarios = [10, 50, 100, 500, 1000, 2000]  # Progressive convergence

println("Simulation parameters:")
println("  Years: $n_years")
println("  Max scenarios: $n_scenarios")
println()

# Generate stochastic forcing (shared across all tests)
Random.seed!(42)  # Reproducible results
println("Generating $n_scenarios stochastic scenarios...")

# Use simple surge distribution: GEV-like with realistic parameters
# Mean ~1.5m, with occasional large surges
surge_dist = Gamma(2.0, 0.75)  # Mean = 1.5m, variance allows large events
surges_matrix = rand(surge_dist, n_scenarios, n_years)

stoch_forcing = StochasticForcing(surges_matrix, 1)
println("  Mean surge across all scenarios: $(round(mean(surges_matrix), digits=2)) m")
println("  Max surge: $(round(maximum(surges_matrix), digits=2)) m")
println("  95th percentile: $(round(quantile(vec(surges_matrix), 0.95), digits=2)) m")
println()

# Create distributional forcing (same distribution each year for simplicity)
println("Creating distributional forcing (EAD mode)...")
dists = [surge_dist for _ in 1:n_years]
dist_forcing = DistributionalForcing(dists, 1)
println()

# Run validation for each test policy
println("="^70)
println("RUNNING CONVERGENCE TESTS")
println("="^70)
println()

results = []

for (policy_name, policy) in test_policies
    println("Testing policy: $policy_name")
    println("-"^70)

    # Run EAD mode once
    println("  Running EAD mode...")
    ead_start = time()
    (ead_cost, ead_damage) = simulate(city, policy, dist_forcing; method=:mc, n_samples=10000)
    ead_time = time() - ead_start
    ead_total = ead_cost + ead_damage

    println("    EAD total: \$$(round(ead_total / 1e6, digits=2)) million")
    println("    Time: $(round(ead_time, digits=3)) seconds")
    println()

    # Run stochastic mode with increasing number of scenarios
    println("  Running stochastic mode with varying scenario counts...")
    stoch_totals = Float64[]
    stoch_means = Float64[]
    stoch_stds = Float64[]

    stoch_start = time()
    for scenario in 1:n_scenarios
        (cost, damage) = simulate(city, policy, stoch_forcing; scenario=scenario)
        push!(stoch_totals, cost + damage)
    end
    stoch_time = time() - stoch_start

    # Calculate progressive means
    for n in test_scenarios
        subset = stoch_totals[1:n]
        push!(stoch_means, mean(subset))
        push!(stoch_stds, std(subset))
    end

    final_mean = mean(stoch_totals)
    final_std = std(stoch_totals)

    println("    Stochastic mean (N=$n_scenarios): \$$(round(final_mean / 1e6, digits=2)) million")
    println("    Stochastic std: \$$(round(final_std / 1e6, digits=2)) million")
    println("    Time: $(round(stoch_time, digits=3)) seconds")
    println()

    # Calculate convergence metrics
    abs_diff = abs(ead_total - final_mean)
    rel_diff = abs_diff / ead_total * 100

    println("  Convergence Analysis:")
    println("    Absolute difference: \$$(round(abs_diff / 1e6, digits=3)) million")
    println("    Relative difference: $(round(rel_diff, digits=2))%")

    # Check if within reasonable tolerance
    # For static policies with Law of Large Numbers, expect <5% difference
    tolerance = 0.05  # 5%
    converged = rel_diff < tolerance * 100

    if converged
        println("    Status: ✓ CONVERGED (within $(tolerance*100)% tolerance)")
    else
        println("    Status: ✗ NOT CONVERGED (exceeds $(tolerance*100)% tolerance)")
        println("    WARNING: This may indicate a bug in mode implementation!")
    end
    println()

    # Progressive convergence
    println("  Progressive convergence:")
    println("    N scenarios  | Mean (\$M)  | Std (\$M)   | Diff from EAD")
    println("    " * "-"^60)
    for (i, n) in enumerate(test_scenarios)
        mean_val = stoch_means[i] / 1e6
        std_val = stoch_stds[i] / 1e6
        diff = abs(stoch_means[i] - ead_total) / ead_total * 100
        @printf("    %-12d | %-10.2f | %-10.2f | %5.2f%%\n", n, mean_val, std_val, diff)
    end
    println()

    # Store results
    push!(results, (
        policy = policy_name,
        ead_total = ead_total,
        stoch_mean = final_mean,
        stoch_std = final_std,
        abs_diff = abs_diff,
        rel_diff = rel_diff,
        converged = converged,
        convergence_history = collect(zip(test_scenarios, stoch_means, stoch_stds))
    ))
end

# Summary
println("="^70)
println("SUMMARY")
println("="^70)
println()

all_converged = all(r.converged for r in results)

println("Policy                | EAD (\$M)  | Stoch Mean (\$M) | Diff (%)  | Status")
println("-"^70)
for r in results
    status = r.converged ? "✓" : "✗"
    @printf("%-20s | %9.2f | %15.2f | %8.2f | %s\n",
            r.policy, r.ead_total/1e6, r.stoch_mean/1e6, r.rel_diff, status)
end
println()

if all_converged
    println("✓ ALL TESTS PASSED: Both modes converge for static policies")
    println()
    println("This validates that:")
    println("  1. EAD integration correctly approximates expected damage")
    println("  2. Stochastic mode correctly samples from surge distributions")
    println("  3. Both modes implement the same underlying physics")
    println()
    exit(0)
else
    println("✗ CONVERGENCE FAILURE: Some policies do not converge")
    println()
    println("This suggests a potential bug in:")
    println("  - EAD integration logic (Phase 6)")
    println("  - Stochastic damage calculation (Phase 5)")
    println("  - Simulation engine state management (Phase 7)")
    println()
    println("Review the policies that failed and compare trace outputs.")
    println()
    exit(1)
end
