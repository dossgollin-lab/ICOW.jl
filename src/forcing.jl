# Forcing types for stochastic and EAD simulation modes
# SOW wrappers for SimOptDecisions integration

using Distributions

"""
    StochasticForcing{T<:Real}

Pre-generated storm surge realizations. Matrix: [n_scenarios, n_years].
"""
struct StochasticForcing{T<:Real}
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
    DistributionalForcing{T<:Real, D<:Distribution}

Distribution-based forcing for EAD simulation. One distribution per year.
"""
struct DistributionalForcing{T<:Real, D<:Distribution}
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

"""Number of scenarios in the forcing data."""
n_scenarios(f::StochasticForcing) = size(f.surges, 1)

"""Number of simulation years in the forcing data."""
n_years(f::StochasticForcing) = size(f.surges, 2)
n_years(f::DistributionalForcing) = length(f.distributions)

"""Get surge height for a specific scenario and year (1-indexed)."""
function get_surge(f::StochasticForcing{T}, scenario::Int, year::Int) where {T}
    @assert 1 <= scenario <= n_scenarios(f) "Scenario out of bounds"
    @assert 1 <= year <= n_years(f) "Year out of bounds"
    f.surges[scenario, year]
end

"""Get surge distribution for a specific year (1-indexed)."""
function get_distribution(f::DistributionalForcing, year::Int)
    @assert 1 <= year <= n_years(f) "Year out of bounds"
    f.distributions[year]
end

# =============================================================================
# SOW Wrappers for SimOptDecisions
# =============================================================================

"""
    EADSOW{T<:Real, D<:Distribution} <: SimOptDecisions.AbstractSOW

SOW wrapper for Expected Annual Damage mode using distributional forcing.
"""
struct EADSOW{T<:Real, D<:Distribution} <: SimOptDecisions.AbstractSOW
    forcing::DistributionalForcing{T, D}
    discount_rate::T
    method::Symbol  # :quad or :mc
end

# Convenience constructor with defaults
function EADSOW(forcing::DistributionalForcing{T, D}; discount_rate::T=zero(T), method::Symbol=:quad) where {T, D}
    EADSOW{T, D}(forcing, discount_rate, method)
end

"""
    StochasticSOW{T<:Real} <: SimOptDecisions.AbstractSOW

SOW wrapper for stochastic mode using pre-generated surge scenarios.
"""
struct StochasticSOW{T<:Real} <: SimOptDecisions.AbstractSOW
    forcing::StochasticForcing{T}
    scenario::Int
    discount_rate::T
end

# Convenience constructor with defaults
function StochasticSOW(forcing::StochasticForcing{T}, scenario::Int; discount_rate::T=zero(T)) where {T}
    @assert 1 <= scenario <= n_scenarios(forcing) "Scenario out of bounds"
    StochasticSOW{T}(forcing, scenario, discount_rate)
end

# SOW accessors
n_years(sow::EADSOW) = n_years(sow.forcing)
n_years(sow::StochasticSOW) = n_years(sow.forcing)
get_surge(sow::StochasticSOW, year::Int) = get_surge(sow.forcing, sow.scenario, year)
get_distribution(sow::EADSOW, year::Int) = get_distribution(sow.forcing, year)
