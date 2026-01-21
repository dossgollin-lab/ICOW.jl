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

# =============================================================================
# Scenario Types for SimOptDecisions
# =============================================================================

"""
    EADScenario{T<:Real, D<:Distribution} <: SimOptDecisions.AbstractScenario

Scenario for Expected Annual Damage mode using distributional forcing.
Contains surge distributions, discount rate, and sea level trajectory.
"""
struct EADScenario{T<:Real, D<:Distribution} <: SimOptDecisions.AbstractScenario
    forcing::DistributionalForcing{T, D}
    discount_rate::T
    method::Symbol  # :quad or :mc
    sea_level::T    # Constant sea level (SLR support: will become TimeSeriesParameter)
end

# Convenience constructor with defaults
function EADScenario(
    forcing::DistributionalForcing{T, D};
    discount_rate::T=zero(T),
    method::Symbol=:quad,
    sea_level::T=zero(T)
) where {T, D}
    EADScenario{T, D}(forcing, discount_rate, method, sea_level)
end

"""
    StochasticScenario{T<:Real} <: SimOptDecisions.AbstractScenario

Scenario for stochastic mode using pre-generated surge realizations.
Contains surge matrix, scenario index, discount rate, and sea level trajectory.
"""
struct StochasticScenario{T<:Real} <: SimOptDecisions.AbstractScenario
    forcing::StochasticForcing{T}
    scenario::Int
    discount_rate::T
    sea_level::T  # Constant sea level (SLR support: will become TimeSeriesParameter)
end

# Convenience constructor with defaults
function StochasticScenario(
    forcing::StochasticForcing{T},
    scenario::Int;
    discount_rate::T=zero(T),
    sea_level::T=zero(T)
) where {T}
    @assert 1 <= scenario <= n_scenarios(forcing) "Scenario out of bounds"
    StochasticScenario{T}(forcing, scenario, discount_rate, sea_level)
end

# Scenario accessors
n_years(s::EADScenario) = n_years(s.forcing)
n_years(s::StochasticScenario) = n_years(s.forcing)
get_surge(s::StochasticScenario, year::Int) = get_surge(s.forcing, s.scenario, year)
get_distribution(s::EADScenario, year::Int) = get_distribution(s.forcing, year)

"""Get sea level for a given year (constant for now, SLR-ready interface)."""
get_sea_level(s::EADScenario{T}, year::Int) where {T} = s.sea_level
get_sea_level(s::StochasticScenario{T}, year::Int) where {T} = s.sea_level

# =============================================================================
# Display methods
# =============================================================================

function Base.show(io::IO, f::StochasticForcing)
    print(io, "StochasticForcing($(n_scenarios(f)) scenarios, $(n_years(f)) years)")
end

function Base.show(io::IO, f::DistributionalForcing{T,D}) where {T,D}
    dist_name = replace(string(D), r"\{.*\}" => "")  # Strip type params
    print(io, "DistributionalForcing($(n_years(f)) years, $dist_name)")
end

function Base.show(io::IO, s::EADScenario)
    print(io, "EADScenario($(n_years(s)) years, method=:$(s.method))")
end

function Base.show(io::IO, s::StochasticScenario)
    print(io, "StochasticScenario(scenario $(s.scenario)/$(n_scenarios(s.forcing)), $(n_years(s)) years)")
end
