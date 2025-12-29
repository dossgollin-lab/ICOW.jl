# Forcing types for stochastic and EAD simulation modes

using Distributions

"""
    StochasticForcing{T<:Real} <: AbstractForcing{T}

Pre-generated storm surge realizations for stochastic simulation.

The `surges` matrix has dimensions `[n_scenarios, n_years]` where each row
is a complete time series of annual maximum surges for one scenario.

# Fields

- `surges::Matrix{T}`: Surge heights in meters, dimensions `[n_scenarios, n_years]`
- `start_year::Int`: Calendar year corresponding to simulation year 1

# Examples

```julia
# 100 scenarios over 50 years, starting in 2020
surges = rand(100, 50) .* 5.0  # Random surges 0-5m
forcing = StochasticForcing(surges, 2020)
```
"""
struct StochasticForcing{T<:Real} <: AbstractForcing{T}
    surges::Matrix{T}
    start_year::Int

    function StochasticForcing{T}(surges::Matrix{T}, start_year::Int) where {T<:Real}
        @assert size(surges, 1) > 0 "Must have at least one scenario"
        @assert size(surges, 2) > 0 "Must have at least one year"
        @assert start_year > 0 "Start year must be positive"
        new{T}(surges, start_year)
    end
end

# Outer constructor with type inference
StochasticForcing(surges::Matrix{T}, start_year::Int) where {T<:Real} =
    StochasticForcing{T}(surges, start_year)

"""
    DistributionalForcing{T<:Real, D<:Distribution} <: AbstractForcing{T}

Distribution-based forcing for Expected Annual Damage (EAD) simulation.

Each year has an associated probability distribution of storm surges.
The EAD mode integrates over these distributions rather than sampling.

# Fields

- `distributions::Vector{D}`: One surge distribution per simulation year
- `start_year::Int`: Calendar year corresponding to simulation year 1

# Examples

```julia
using Distributions
# 50 years of GEV distributions (stationary)
dists = [GeneralizedExtremeValue(1.0, 0.5, 0.1) for _ in 1:50]
forcing = DistributionalForcing(dists, 2020)
```
"""
struct DistributionalForcing{T<:Real, D<:Distribution} <: AbstractForcing{T}
    distributions::Vector{D}
    start_year::Int

    function DistributionalForcing{T,D}(distributions::Vector{D}, start_year::Int) where {T<:Real, D<:Distribution}
        @assert length(distributions) > 0 "Must have at least one distribution"
        @assert start_year > 0 "Start year must be positive"
        new{T,D}(distributions, start_year)
    end
end

# Outer constructor with type inference
function DistributionalForcing(distributions::Vector{D}, start_year::Int) where {D<:Distribution}
    T = Float64  # Default to Float64 for distribution-based forcing
    DistributionalForcing{T,D}(distributions, start_year)
end

# Access functions

"""
    n_scenarios(f::StochasticForcing) -> Int

Number of scenarios in the forcing data.
"""
n_scenarios(f::StochasticForcing) = size(f.surges, 1)

"""
    n_years(f::AbstractForcing) -> Int

Number of simulation years in the forcing data.
"""
n_years(f::StochasticForcing) = size(f.surges, 2)
n_years(f::DistributionalForcing) = length(f.distributions)

"""
    get_surge(f::StochasticForcing, scenario::Int, year::Int) -> T

Get the surge height for a specific scenario and simulation year.
Year is 1-indexed (simulation year, not calendar year).
"""
function get_surge(f::StochasticForcing{T}, scenario::Int, year::Int) where {T}
    @assert 1 <= scenario <= n_scenarios(f) "Scenario out of bounds"
    @assert 1 <= year <= n_years(f) "Year out of bounds"
    f.surges[scenario, year]
end

"""
    get_distribution(f::DistributionalForcing, year::Int) -> Distribution

Get the surge distribution for a specific simulation year.
Year is 1-indexed (simulation year, not calendar year).
"""
function get_distribution(f::DistributionalForcing, year::Int)
    @assert 1 <= year <= n_years(f) "Year out of bounds"
    f.distributions[year]
end
