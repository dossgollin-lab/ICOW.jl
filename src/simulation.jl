# Simulation engine implementing SimOptDecisions 5-callback interface

using Random

# ============================================================================
# Callback 1: initialize
# ============================================================================

function SimOptDecisions.initialize(
    ::CityParameters{T},
    scenario::EADScenario{T,D},
    ::AbstractRNG
) where {T<:Real, D<:Distribution}
    initial_sea_level = scenario.sea_level[1]
    State(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)), initial_sea_level)
end

function SimOptDecisions.initialize(
    ::CityParameters{T},
    scenario::StochasticScenario{T},
    ::AbstractRNG
) where {T<:Real}
    initial_sea_level = scenario.sea_level[1]
    State(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)), initial_sea_level)
end

# ============================================================================
# Callback 2: time_axis
# ============================================================================

SimOptDecisions.time_axis(::CityParameters, s::EADScenario) = 1:n_years(s)
SimOptDecisions.time_axis(::CityParameters, s::StochasticScenario) = 1:n_years(s)

# ============================================================================
# Callback 3: get_action (defined in policies.jl)
# ============================================================================

# ============================================================================
# Callback 4: run_timestep
# ============================================================================

function SimOptDecisions.run_timestep(
    state::State{T},
    action::Levers{T},
    t::SimOptDecisions.TimeStep,
    config::CityParameters{T},
    scenario::EADScenario{T,D},
    ::AbstractRNG
) where {T<:Real, D<:Distribution}
    # Enforce irreversibility
    new_levers = max(state.current_levers, action)

    # Marginal investment cost
    investment = _marginal_cost(config, state.current_levers, new_levers)

    # EAD damage
    damage = calculate_expected_damage(config, new_levers, scenario.forcing, t.val; method=scenario.method)

    # Update sea level
    new_sea_level = get_sea_level(scenario, t)

    return (State(new_levers, new_sea_level), (investment=investment, damage=damage))
end

function SimOptDecisions.run_timestep(
    state::State{T},
    action::Levers{T},
    t::SimOptDecisions.TimeStep,
    config::CityParameters{T},
    scenario::StochasticScenario{T},
    rng::AbstractRNG
) where {T<:Real}
    # Enforce irreversibility
    new_levers = max(state.current_levers, action)

    # Marginal investment cost
    investment = _marginal_cost(config, state.current_levers, new_levers)

    # Stochastic damage
    h_raw = get_surge(scenario, t.val)
    damage = calculate_event_damage_stochastic(h_raw, config, new_levers, rng)

    # Update sea level
    new_sea_level = get_sea_level(scenario, t)

    return (State(new_levers, new_sea_level), (investment=investment, damage=damage))
end

# ============================================================================
# Callback 5: compute_outcome
# ============================================================================

function SimOptDecisions.compute_outcome(
    step_records::Vector,
    ::CityParameters{T},
    scenario::EADScenario{T,D}
) where {T<:Real, D<:Distribution}
    total_investment = zero(T)
    total_damage = zero(T)

    for (year, record) in enumerate(step_records)
        df = SimOptDecisions.discount_factor(scenario.discount_rate, year)
        total_investment += record.investment * df
        total_damage += record.damage * df
    end

    return (investment=total_investment, damage=total_damage)
end

function SimOptDecisions.compute_outcome(
    step_records::Vector,
    ::CityParameters{T},
    scenario::StochasticScenario{T}
) where {T<:Real}
    total_investment = zero(T)
    total_damage = zero(T)

    for (year, record) in enumerate(step_records)
        df = SimOptDecisions.discount_factor(scenario.discount_rate, year)
        total_investment += record.investment * df
        total_damage += record.damage * df
    end

    return (investment=total_investment, damage=total_damage)
end

# ============================================================================
# Internal helpers
# ============================================================================

function _marginal_cost(city::CityParameters{T}, old::Levers{T}, new::Levers{T}) where {T<:Real}
    max(zero(T), calculate_investment_cost(city, new) - calculate_investment_cost(city, old))
end
