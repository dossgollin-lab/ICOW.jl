# Mode Convergence Validation
# Demonstrates that EAD mode approximates mean of stochastic mode
# This is NOT a unit test - it's a validation/demonstration script

using ICOW
using Random
using Distributions
using Statistics

println("Mode Convergence Validation")
println("=" ^ 60)

# Setup
city = CityParameters{Float64}()
policy = StaticPolicy(Levers(0.0, 0.0, 0.0, 2.0, 0.0))  # Small dike to ensure damage

# Generate stochastic forcing (many scenarios)
n_scenarios = 2000
n_years = 20
Random.seed!(456)
surge_dist = LogNormal(1.0, 0.6)  # Naturally non-negative
surges = rand(surge_dist, n_scenarios, n_years)
stoch_forcing = StochasticForcing(surges, 1)

# Run stochastic simulations
println("\nRunning $n_scenarios stochastic simulations...")
stoch_results = Vector{Tuple{Float64, Float64}}(undef, n_scenarios)
for i in 1:n_scenarios
    stoch_results[i] = simulate(city, policy, stoch_forcing; scenario=i)
    if i % 500 == 0
        println("  Completed $i scenarios")
    end
end

# Statistics from stochastic mode
stoch_costs = [r[1] for r in stoch_results]
stoch_damages = [r[2] for r in stoch_results]
mean_stoch_cost = mean(stoch_costs)
mean_stoch_damage = mean(stoch_damages)
std_stoch_cost = std(stoch_costs)
std_stoch_damage = std(stoch_damages)

println("\nStochastic Mode Results:")
println("  Mean Cost:   \$$(round(mean_stoch_cost/1e9, digits=2))B ± \$$(round(std_stoch_cost/1e9, digits=2))B")
println("  Mean Damage: \$$(round(mean_stoch_damage/1e9, digits=2))B ± \$$(round(std_stoch_damage/1e9, digits=2))B")

# Run EAD simulation
println("\nRunning EAD simulation...")
dists = [LogNormal(1.0, 0.6) for _ in 1:n_years]
ead_forcing = DistributionalForcing(dists, 1)
(ead_cost, ead_damage) = simulate(city, policy, ead_forcing; method=:mc, n_samples=5000)

println("\nEAD Mode Results:")
println("  Cost:   \$$(round(ead_cost/1e9, digits=2))B")
println("  Damage: \$$(round(ead_damage/1e9, digits=2))B")

# Convergence analysis
cost_error = abs(ead_cost - mean_stoch_cost) / mean_stoch_cost * 100
damage_error = abs(ead_damage - mean_stoch_damage) / mean_stoch_damage * 100

println("\nConvergence Analysis:")
println("  Cost Error:   $(round(cost_error, digits=1))%")
println("  Damage Error: $(round(damage_error, digits=1))%")
println()

if damage_error < 15.0
    println("✓ PASS: Modes converge within 15% tolerance")
else
    println("⚠ WARN: Modes differ by >15% (may need more scenarios/samples)")
end

println("\nNote: Convergence improves with:")
println("  - More stochastic scenarios (currently $n_scenarios)")
println("  - More MC samples in EAD mode (currently 5000)")
println("  - Longer simulation horizons (currently $n_years years)")
