using Test
using ICOW
using Distributions

@testset "Forcing Types" begin
    @testset "StochasticForcing" begin
        surges = collect(reshape(1.0:20.0, 4, 5))  # 4 scenarios, 5 years
        forcing = StochasticForcing(surges)

        @test forcing isa StochasticForcing{Float64}
        @test n_scenarios(forcing) == 4
        @test n_years(forcing) == 5
        @test get_surge(forcing, 1, 1) == 1.0
        @test get_surge(forcing, 4, 5) == 20.0

        # Validation
        @test_throws AssertionError StochasticForcing(zeros(0, 10))
        @test_throws AssertionError StochasticForcing(zeros(10, 0))

        # Bounds checking
        @test_throws AssertionError get_surge(forcing, 0, 1)
        @test_throws AssertionError get_surge(forcing, 5, 1)
    end

    @testset "DistributionalForcing" begin
        dists = [GeneralizedExtremeValue(Float64(i), 0.5, 0.1) for i in 1:5]
        forcing = DistributionalForcing(dists)

        @test forcing isa DistributionalForcing{Float64, GeneralizedExtremeValue{Float64}}
        @test n_years(forcing) == 5
        @test get_distribution(forcing, 1) === dists[1]

        # Validation
        @test_throws AssertionError DistributionalForcing(GeneralizedExtremeValue{Float64}[])

        # Bounds checking
        @test_throws AssertionError get_distribution(forcing, 0)
        @test_throws AssertionError get_distribution(forcing, 6)
    end
end
