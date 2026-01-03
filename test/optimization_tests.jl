using Test
using ICOW
using Distributions

@testset "bounds" begin
    city = CityParameters()
    (lb, ub) = bounds(StaticPolicy, city)

    # Returns vectors of correct size
    @test length(lb) == 5
    @test length(ub) == 5

    # Lower bounds are non-negative
    @test all(lb .>= 0)

    # Upper bounds respect feasibility constraint: W + B + D ≤ H_city
    @test ub[1] + ub[4] + ub[5] <= city.H_city  # W + D + B
    @test ub[2] == city.H_city  # R unconstrained
    @test ub[3] < 1.0           # P < 1 to avoid division by zero
end

@testset "make_objective" begin
    city = CityParameters()
    forcing = DistributionalForcing([truncated(Normal(1.0, 0.5), lower=0.0) for _ in 1:10], 2020)
    ensemble = [(city, forcing)]

    f = make_objective(StaticPolicy, ensemble, 0.03)

    # Valid parameters return (fx, gx, hx) tuple for Metaheuristics
    result = f([1.0, 0.0, 0.2, 2.0, 1.0])
    @test result isa Tuple
    @test length(result) == 3  # (fx, gx, hx)
    fx, gx, hx = result
    @test length(fx) == 2  # [cost, damage]
    @test all(isfinite.(fx))
    @test all(fx .>= 0)

    # Infeasible parameters return large penalty with constraint violation
    result_infeasible = f([100.0, 0.0, 0.0, 0.0, 0.0])  # W > H_city
    fx_inf, gx_inf, _ = result_infeasible
    @test all(fx_inf .>= 1e19)
    @test gx_inf[1] >= 1e19  # constraint violation indicator
end

@testset "optimize (NSGA-II)" begin
    city = CityParameters()
    forcing = DistributionalForcing([truncated(Normal(1.0, 0.5), lower=0.0) for _ in 1:10], 2020)
    ensemble = [(city, forcing)]

    # Small optimization run for testing
    result = optimize(StaticPolicy, ensemble, 0.03;
        n_generations=5, population_size=10, seed=42)

    @test result isa OptimizationResult
    @test size(result.pareto_front, 2) == 2  # [cost, damage]
    @test size(result.pareto_set, 2) == 5    # 5 parameters
    @test size(result.pareto_front, 1) == size(result.pareto_set, 1)  # same n_solutions
    @test result.n_evaluations > 0
end

@testset "optimize_scalar" begin
    city = CityParameters()
    forcing = DistributionalForcing([truncated(Normal(1.0, 0.5), lower=0.0) for _ in 1:10], 2020)
    ensemble = [(city, forcing)]

    # Small optimization run for testing
    result = optimize_scalar(StaticPolicy, ensemble, 0.03;
        n_generations=5, population_size=10, seed=42)

    @test result isa OptimizationResult
    @test size(result.pareto_front) == (1, 2)  # single solution
    @test size(result.pareto_set) == (1, 5)
    @test result.n_evaluations > 0
end

@testset "aggregation" begin
    city = CityParameters()
    forcing = DistributionalForcing([truncated(Normal(1.0, 0.5), lower=0.0) for _ in 1:10], 2020)

    # Multi-member ensemble
    ensemble = [(city, forcing), (city, forcing)]

    # mean aggregation (default)
    f_mean = make_objective(StaticPolicy, ensemble, 0.03)
    fx_mean, _, _ = f_mean([1.0, 0.0, 0.2, 2.0, 1.0])
    @test all(isfinite.(fx_mean))

    # custom aggregation
    f_max = make_objective(StaticPolicy, ensemble, 0.03; aggregate=maximum)
    fx_max, _, _ = f_max([1.0, 0.0, 0.2, 2.0, 1.0])
    @test all(isfinite.(fx_max))
end

@testset "pareto front extraction" begin
    city = CityParameters()
    forcing = DistributionalForcing([truncated(Normal(1.0, 0.5), lower=0.0) for _ in 1:10], 2020)
    ensemble = [(city, forcing)]

    result = optimize(StaticPolicy, ensemble, 0.03;
        n_generations=5, population_size=10, seed=42)

    # All solutions have finite objectives (no Inf/NaN from failed simulations)
    @test all(isfinite.(result.pareto_front))

    # All parameter values are within bounds
    (lb, ub) = bounds(StaticPolicy, city)
    for i in 1:size(result.pareto_set, 1)
        @test all(result.pareto_set[i, :] .>= lb)
        @test all(result.pareto_set[i, :] .<= ub)
    end
end

@testset "cost-damage tradeoff" begin
    city = CityParameters()
    forcing = DistributionalForcing([truncated(Normal(1.5, 0.5), lower=0.0) for _ in 1:20], 2020)
    ensemble = [(city, forcing)]

    f = make_objective(StaticPolicy, ensemble, 0.03)

    # No protection: zero investment, high damage
    fx_none, _, _ = f([0.0, 0.0, 0.0, 0.0, 0.0])
    cost_none, damage_none = fx_none

    # High protection: higher investment, lower damage
    fx_high, _, _ = f([0.0, 0.0, 0.0, 5.0, 2.0])
    cost_high, damage_high = fx_high

    # Tradeoff: more investment should reduce damage
    @test cost_high > cost_none
    @test damage_high < damage_none
end
