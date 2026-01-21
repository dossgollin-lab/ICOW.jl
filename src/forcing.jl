# Forcing types and Scenario wrappers for SimOptDecisions

using Distributions

"""
    StochasticForcing{T<:Real}

Pre-generated storm surge realizations. Matrix: [n_scenarios, n_years].
"""
struct StochasticForcing{T<:Real}
    surges::Matrix{T}

    function StochasticForcing{T}(surges::Matrix{T}) where {T<:Real}
        @assert size(surges, 1) > 0 "Must have at least one scenario"
        @assert size(surges, 2) > 0 "Must have at least one year"
        new{T}(surges)
    end
end

StochasticForcing(surges::Matrix{T}) where {T<:Real} = StochasticForcing{T}(surges)

"""
    DistributionalForcing{T<:Real, D<:Distribution}

Distribution-based forcing for EAD simulation. One distribution per year.
"""
struct DistributionalForcing{T<:Real, D<:Distribution}
    distributions::Vector{D}

    function DistributionalForcing{T,D}(distributions::Vector{D}) where {T<:Real, D<:Distribution}
        @assert length(distributions) > 0 "Must have at least one distribution"
        new{T,D}(distributions)
    end
end

function DistributionalForcing(distributions::Vector{D}) where {D<:Distribution}
    DistributionalForcing{Float64,D}(distributions)
end

# Access functions
n_scenarios(f::StochasticForcing) = size(f.surges, 1)
n_years(f::StochasticForcing) = size(f.surges, 2)
n_years(f::DistributionalForcing) = length(f.distributions)

function get_surge(f::StochasticForcing{T}, scenario::Int, year::Int) where {T}
    @assert 1 <= scenario <= n_scenarios(f) "Scenario out of bounds"
    @assert 1 <= year <= n_years(f) "Year out of bounds"
    f.surges[scenario, year]
end

function get_distribution(f::DistributionalForcing, year::Int)
    @assert 1 <= year <= n_years(f) "Year out of bounds"
    f.distributions[year]
end

# =============================================================================
# Scenario Types for SimOptDecisions
# =============================================================================

"""
    EADScenario{T<:Real, D<:Distribution} <: SimOptDecisions.AbstractScenario

Scenario for Expected Annual Damage mode.
"""
struct EADScenario{T<:Real, D<:Distribution} <: SimOptDecisions.AbstractScenario
    forcing::DistributionalForcing{T, D}
    discount_rate::T
    method::Symbol
    sea_level::SimOptDecisions.TimeSeriesParameter{T,Int}
end

function EADScenario(
    forcing::DistributionalForcing{T, D};
    discount_rate::T=zero(T),
    method::Symbol=:quad,
    sea_level::SimOptDecisions.TimeSeriesParameter{T,Int}=SimOptDecisions.TimeSeriesParameter(
        collect(1:n_years(forcing)), zeros(T, n_years(forcing))
    )
) where {T, D}
    EADScenario{T, D}(forcing, discount_rate, method, sea_level)
end

"""
    StochasticScenario{T<:Real} <: SimOptDecisions.AbstractScenario

Scenario for stochastic mode using pre-generated surge realizations.
"""
struct StochasticScenario{T<:Real} <: SimOptDecisions.AbstractScenario
    forcing::StochasticForcing{T}
    scenario::Int
    discount_rate::T
    sea_level::SimOptDecisions.TimeSeriesParameter{T,Int}
end

function StochasticScenario(
    forcing::StochasticForcing{T},
    scenario::Int;
    discount_rate::T=zero(T),
    sea_level::SimOptDecisions.TimeSeriesParameter{T,Int}=SimOptDecisions.TimeSeriesParameter(
        collect(1:n_years(forcing)), zeros(T, n_years(forcing))
    )
) where {T}
    @assert 1 <= scenario <= n_scenarios(forcing) "Scenario out of bounds"
    StochasticScenario{T}(forcing, scenario, discount_rate, sea_level)
end

# Scenario accessors
n_years(s::EADScenario) = n_years(s.forcing)
n_years(s::StochasticScenario) = n_years(s.forcing)
get_surge(s::StochasticScenario, year::Int) = get_surge(s.forcing, s.scenario, year)
get_distribution(s::EADScenario, year::Int) = get_distribution(s.forcing, year)

"""Get sea level for a given year via TimeSeriesParameter indexing."""
get_sea_level(s::EADScenario, t::SimOptDecisions.TimeStep) = s.sea_level[t]
get_sea_level(s::StochasticScenario, t::SimOptDecisions.TimeStep) = s.sea_level[t]

# Display methods
function Base.show(io::IO, f::StochasticForcing)
    print(io, "StochasticForcing($(n_scenarios(f)) scenarios, $(n_years(f)) years)")
end

function Base.show(io::IO, f::DistributionalForcing{T,D}) where {T,D}
    dist_name = replace(string(D), r"\{.*\}" => "")
    print(io, "DistributionalForcing($(n_years(f)) years, $dist_name)")
end

function Base.show(io::IO, s::EADScenario)
    print(io, "EADScenario($(n_years(s)) years, method=:$(s.method))")
end

function Base.show(io::IO, s::StochasticScenario)
    print(io, "StochasticScenario(scenario $(s.scenario)/$(n_scenarios(s.forcing)), $(n_years(s)) years)")
end
