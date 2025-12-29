using Test
using ICOW
using Distributions

@testset "Forcing Types" begin

    @testset "StochasticForcing" begin
        @testset "Construction" begin
            # Valid construction
            surges = rand(100, 50)
            forcing = StochasticForcing(surges, 2020)
            @test forcing.surges === surges
            @test forcing.start_year == 2020

            # Type stability
            @test forcing isa StochasticForcing{Float64}

            # Single precision
            surges32 = rand(Float32, 10, 5)
            forcing32 = StochasticForcing(surges32, 2020)
            @test forcing32 isa StochasticForcing{Float32}
        end

        @testset "Validation" begin
            # n_scenarios > 0; must have at least one scenario
            @test_throws AssertionError StochasticForcing(zeros(0, 10), 2020)

            # n_years > 0; must have at least one year
            @test_throws AssertionError StochasticForcing(zeros(10, 0), 2020)

            # start_year > 0; calendar year must be positive
            @test_throws AssertionError StochasticForcing(zeros(10, 10), 0)
            @test_throws AssertionError StochasticForcing(zeros(10, 10), -1)
        end

        @testset "Access functions" begin
            surges = collect(reshape(1.0:20.0, 4, 5))  # 4 scenarios, 5 years
            forcing = StochasticForcing(surges, 2020)

            @test n_scenarios(forcing) == 4
            @test n_years(forcing) == 5

            # get_surge returns correct values
            @test get_surge(forcing, 1, 1) == 1.0
            @test get_surge(forcing, 4, 5) == 20.0
            @test get_surge(forcing, 2, 3) == surges[2, 3]

            # Bounds checking
            @test_throws AssertionError get_surge(forcing, 0, 1)
            @test_throws AssertionError get_surge(forcing, 5, 1)
            @test_throws AssertionError get_surge(forcing, 1, 0)
            @test_throws AssertionError get_surge(forcing, 1, 6)
        end

        @testset "Type stability" begin
            surges = rand(10, 5)
            forcing = StochasticForcing(surges, 2020)

            @test @inferred(n_scenarios(forcing)) == 10
            @test @inferred(n_years(forcing)) == 5
            @test @inferred(get_surge(forcing, 1, 1)) isa Float64
        end
    end

    @testset "DistributionalForcing" begin
        @testset "Construction" begin
            # Valid construction with GEV distributions
            dists = [GeneralizedExtremeValue(1.0, 0.5, 0.1) for _ in 1:50]
            forcing = DistributionalForcing(dists, 2020)
            @test forcing.distributions === dists
            @test forcing.start_year == 2020

            # Type includes distribution type
            @test forcing isa DistributionalForcing{Float64, GeneralizedExtremeValue{Float64}}
        end

        @testset "Validation" begin
            # length > 0; must have at least one distribution
            @test_throws AssertionError DistributionalForcing(GeneralizedExtremeValue{Float64}[], 2020)

            # start_year > 0; calendar year must be positive
            dists = [GeneralizedExtremeValue(1.0, 0.5, 0.1)]
            @test_throws AssertionError DistributionalForcing(dists, 0)
            @test_throws AssertionError DistributionalForcing(dists, -1)
        end

        @testset "Access functions" begin
            dists = [GeneralizedExtremeValue(Float64(i), 0.5, 0.1) for i in 1:5]
            forcing = DistributionalForcing(dists, 2020)

            @test n_years(forcing) == 5

            # get_distribution returns correct distribution
            @test get_distribution(forcing, 1) === dists[1]
            @test get_distribution(forcing, 5) === dists[5]

            # Bounds checking
            @test_throws AssertionError get_distribution(forcing, 0)
            @test_throws AssertionError get_distribution(forcing, 6)
        end

        @testset "Type stability" begin
            dists = [GeneralizedExtremeValue(1.0, 0.5, 0.1) for _ in 1:5]
            forcing = DistributionalForcing(dists, 2020)

            @test @inferred(n_years(forcing)) == 5
            @test @inferred(get_distribution(forcing, 1)) isa GeneralizedExtremeValue
        end
    end

end
