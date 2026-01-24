# Scenario types for ICOW simulations
# Scenarios represent uncertain futures (forcing data)

using Distributions

"""
    EADScenario{T,D} <: SimOptDecisions.AbstractScenario

Scenario for Expected Annual Damage mode using distributional forcing.
"""
struct EADScenario{T<:AbstractFloat,D<:Distribution} <: SimOptDecisions.AbstractScenario
    forcing::DistributionalForcing{T,D}
    discount_rate::T
    method::Symbol  # :quad or :mc
end

function EADScenario(
    forcing::DistributionalForcing{T,D};
    discount_rate::T=zero(T),
    method::Symbol=:quad
) where {T,D}
    EADScenario{T,D}(forcing, discount_rate, method)
end

"""
    StochasticScenario{T} <: SimOptDecisions.AbstractScenario

Scenario for stochastic mode using pre-generated surge realizations.
"""
struct StochasticScenario{T<:AbstractFloat} <: SimOptDecisions.AbstractScenario
    forcing::StochasticForcing{T}
    scenario_idx::Int
    discount_rate::T
end

function StochasticScenario(
    forcing::StochasticForcing{T},
    scenario_idx::Int;
    discount_rate::T=zero(T)
) where {T}
    @assert 1 <= scenario_idx <= n_scenarios(forcing) "Scenario index out of bounds"
    StochasticScenario{T}(forcing, scenario_idx, discount_rate)
end

# Accessors
n_years(s::EADScenario) = n_years(s.forcing)
n_years(s::StochasticScenario) = n_years(s.forcing)
get_surge(s::StochasticScenario, year::Int) = get_surge(s.forcing, s.scenario_idx, year)
get_distribution(s::EADScenario, year::Int) = get_distribution(s.forcing, year)

# Display
function Base.show(io::IO, s::EADScenario)
    print(io, "EADScenario($(n_years(s)) years, method=:$(s.method))")
end

function Base.show(io::IO, s::StochasticScenario)
    print(io, "StochasticScenario(idx=$(s.scenario_idx), $(n_years(s)) years)")
end
