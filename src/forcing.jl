# Forcing types for ICOW simulations
# Forcing data = external inputs (storm surge distributions or realizations)

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

# Convenience constructor with start_year=1 default
StochasticForcing(surges::Matrix{T}) where {T<:Real} =
    StochasticForcing(surges, 1)

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

# Convenience constructor with start_year=1 default
DistributionalForcing(distributions::Vector{D}) where {D<:Distribution} =
    DistributionalForcing(distributions, 1)

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

# Display methods

function Base.show(io::IO, f::StochasticForcing)
    print(io, "StochasticForcing($(n_scenarios(f)) scenarios, $(n_years(f)) years)")
end

function Base.show(io::IO, f::DistributionalForcing{T,D}) where {T,D}
    dist_name = replace(string(D), r"\{.*\}" => "")  # Strip type params
    print(io, "DistributionalForcing($(n_years(f)) years, $dist_name)")
end
