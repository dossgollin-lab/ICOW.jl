using ICOW
using ICOW.Stochastic
using SimOptDecisions
using Test

@testset "StochasticConfig" begin
    # Default construction
    config = StochasticConfig()
    @test config.H_city == 17.0
    @test config.V_city == 1.5e12

    # Custom construction
    config = StochasticConfig(H_city=20.0, V_city=2e12)
    @test config.H_city == 20.0
    @test config.V_city == 2e12

    # Type parameterization
    @test StochasticConfig{Float32}(H_city=17.0f0).H_city isa Float32
end

@testset "validate_config" begin
    # Valid config passes
    @test validate_config(StochasticConfig()) === nothing

    # V_city > 0; city value must be positive
    @test_throws AssertionError validate_config(StochasticConfig(V_city=-1.0))
    @test_throws AssertionError validate_config(StochasticConfig(V_city=0.0))

    # Fractions in [0, 1]
    @test_throws AssertionError validate_config(StochasticConfig(f_damage=1.5))
    @test_throws AssertionError validate_config(StochasticConfig(t_fail=-0.1))

    # f_runup >= 1.0; runup should amplify
    @test_throws AssertionError validate_config(StochasticConfig(f_runup=0.9))
end

@testset "is_feasible" begin
    config = StochasticConfig()  # H_city = 17.0

    # Feasible
    @test is_feasible(FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0), config)
    @test is_feasible(FloodDefenses(16.9, 0.0, 0.0, 0.0, 0.0), config)  # W < H_city

    # W = H_city is infeasible (strict inequality required to avoid division by zero)
    @test !is_feasible(FloodDefenses(17.0, 0.0, 0.0, 0.0, 0.0), config)

    # Infeasible
    @test !is_feasible(FloodDefenses(18.0, 0.0, 0.0, 0.0, 0.0), config)  # W > H_city
    @test !is_feasible(FloodDefenses(10.0, 0.0, 0.0, 5.0, 5.0), config)  # W+B+D > H_city
end

@testset "StaticPolicy reparameterization" begin
    config = StochasticConfig()  # H_city = 17.0

    # Zero policy produces zero defenses
    policy = StaticPolicy(a_frac=0.0, w_frac=0.0, b_frac=0.0, r_frac=0.0, P=0.0)
    fd = FloodDefenses(policy, config)
    @test fd.W == 0.0 && fd.B == 0.0 && fd.D == 0.0 && fd.R == 0.0 && fd.P == 0.0

    # Full budget (a_frac=1) with all to W (w_frac=1) produces W = H_city
    # Note: This is infeasible for simulation (W must be < H_city), but the
    # conversion itself works. Feasibility is checked separately.
    policy = StaticPolicy(a_frac=1.0, w_frac=1.0, b_frac=0.0, r_frac=0.0, P=0.0)
    fd = FloodDefenses(policy, config)
    @test fd.W == 17.0  # W = a_frac * w_frac * H_city
    @test fd.B == 0.0 && fd.D == 0.0
    @test !is_feasible(fd, config)  # W = H_city is infeasible

    # Full budget, half to W, half remaining to B
    policy = StaticPolicy(a_frac=1.0, w_frac=0.5, b_frac=0.5, r_frac=0.0, P=0.0)
    fd = FloodDefenses(policy, config)
    @test fd.W ≈ 8.5   # 0.5 * 17
    @test fd.B ≈ 4.25  # 0.5 * (17 - 8.5)
    @test fd.D ≈ 4.25  # remaining

    # Resistance is independent
    policy = StaticPolicy(a_frac=0.5, w_frac=0.0, b_frac=0.0, r_frac=0.5, P=0.5)
    fd = FloodDefenses(policy, config)
    @test fd.R ≈ 8.5  # r_frac * H_city
    @test fd.P == 0.5

    # Reparameterized policies are feasible except when W = H_city (a=1, w=1)
    for a in [0.0, 0.5, 0.99], w in [0.0, 0.5, 1.0], b in [0.0, 0.5, 1.0]
        policy = StaticPolicy(a_frac=a, w_frac=w, b_frac=b, r_frac=0.5, P=0.5)
        fd = FloodDefenses(policy, config)
        @test is_feasible(fd, config)
    end
end

@testset "StochasticScenario" begin
    scenario = StochasticScenario(surges=[1.0, 2.0, 3.0], discount_rate=0.03)
    @test length(SimOptDecisions.value(scenario.surges)) == 3
    @test SimOptDecisions.value(scenario.discount_rate) == 0.03
end

@testset "StochasticState" begin
    state = StochasticState{Float64}()
    @test state.defenses == FloodDefenses(0.0, 0.0, 0.0, 0.0, 0.0)

    state.defenses = FloodDefenses(1.0, 2.0, 0.3, 3.0, 1.0)
    @test state.defenses.W == 1.0
end
