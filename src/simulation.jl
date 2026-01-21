# Simulation engine for the iCOW model
# Implements SimOptDecisions 5-callback interface

using Random

# ============================================================================
# Callback 1: initialize
# Create initial state for simulation
# ============================================================================

"""
    SimOptDecisions.initialize(config::CityParameters, scenario::EADScenario, rng)

Initialize simulation state for EAD mode.
Returns State with zero levers and initial sea level from scenario.
"""
function SimOptDecisions.initialize(
    config::CityParameters{T},
    scenario::EADScenario{T,D},
    ::AbstractRNG
) where {T<:Real, D<:Distribution}
    initial_sea_level = get_sea_level(scenario, 1)
    State(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)), initial_sea_level)
end

"""
    SimOptDecisions.initialize(config::CityParameters, scenario::StochasticScenario, rng)

Initialize simulation state for stochastic mode.
Returns State with zero levers and initial sea level from scenario.
"""
function SimOptDecisions.initialize(
    config::CityParameters{T},
    scenario::StochasticScenario{T},
    ::AbstractRNG
) where {T<:Real}
    initial_sea_level = get_sea_level(scenario, 1)
    State(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)), initial_sea_level)
end

# ============================================================================
# Callback 2: time_axis
# Define simulation time points
# ============================================================================

"""
    SimOptDecisions.time_axis(config::CityParameters, scenario::EADScenario)

Return time axis for EAD simulation (1:n_years).
"""
function SimOptDecisions.time_axis(
    ::CityParameters,
    scenario::EADScenario
)
    return 1:n_years(scenario)
end

"""
    SimOptDecisions.time_axis(config::CityParameters, scenario::StochasticScenario)

Return time axis for stochastic simulation (1:n_years).
"""
function SimOptDecisions.time_axis(
    ::CityParameters,
    scenario::StochasticScenario
)
    return 1:n_years(scenario)
end

# ============================================================================
# Callback 3: get_action (defined in policies.jl)
# ============================================================================

# See policies.jl for get_action implementations

# ============================================================================
# Callback 4: run_timestep
# Execute one timestep of simulation
# ============================================================================

"""
    SimOptDecisions.run_timestep(state, action, t, config, scenario::EADScenario, rng)

Execute one timestep for EAD mode.
Returns (new_state, step_record) where step_record contains undiscounted values.
"""
function SimOptDecisions.run_timestep(
    state::State{T},
    action::Levers{T},
    t::SimOptDecisions.TimeStep,
    config::CityParameters{T},
    scenario::EADScenario{T,D},
    ::AbstractRNG
) where {T<:Real, D<:Distribution}
    year = t.val

    # Enforce irreversibility: can only increase protection
    new_levers = max(state.current_levers, action)

    # Calculate marginal investment cost (undiscounted)
    investment = _marginal_cost(config, state.current_levers, new_levers)

    # Calculate EAD damage (undiscounted)
    damage = calculate_expected_damage(config, new_levers, scenario.forcing, year; method=scenario.method)

    # Update sea level from scenario
    new_sea_level = get_sea_level(scenario, year)

    # Create new state
    new_state = State(new_levers, new_sea_level)

    # Step record with undiscounted values (discounting happens in compute_outcome)
    step_record = (investment=investment, damage=damage)

    return (new_state, step_record)
end

"""
    SimOptDecisions.run_timestep(state, action, t, config, scenario::StochasticScenario, rng)

Execute one timestep for stochastic mode.
Returns (new_state, step_record) where step_record contains undiscounted values.
"""
function SimOptDecisions.run_timestep(
    state::State{T},
    action::Levers{T},
    t::SimOptDecisions.TimeStep,
    config::CityParameters{T},
    scenario::StochasticScenario{T},
    rng::AbstractRNG
) where {T<:Real}
    year = t.val

    # Enforce irreversibility: can only increase protection
    new_levers = max(state.current_levers, action)

    # Calculate marginal investment cost (undiscounted)
    investment = _marginal_cost(config, state.current_levers, new_levers)

    # Get surge and calculate stochastic damage (undiscounted)
    h_raw = get_surge(scenario, year)
    damage = calculate_event_damage_stochastic(h_raw, config, new_levers, rng)

    # Update sea level from scenario
    new_sea_level = get_sea_level(scenario, year)

    # Create new state
    new_state = State(new_levers, new_sea_level)

    # Step record with undiscounted values
    step_record = (investment=investment, damage=damage)

    return (new_state, step_record)
end

# ============================================================================
# Callback 5: compute_outcome
# Aggregate step records into final outcome
# ============================================================================

"""
    SimOptDecisions.compute_outcome(step_records, config, scenario::EADScenario)

Aggregate step records into final outcome with NPV discounting.
Returns (investment=..., damage=...) as discounted totals.
"""
function SimOptDecisions.compute_outcome(
    step_records::Vector,
    config::CityParameters{T},
    scenario::EADScenario{T,D}
) where {T<:Real, D<:Distribution}
    discount_rate = scenario.discount_rate

    # Sum discounted values
    total_investment = zero(T)
    total_damage = zero(T)

    for (year, record) in enumerate(step_records)
        df = SimOptDecisions.discount_factor(discount_rate, year)
        total_investment += record.investment * df
        total_damage += record.damage * df
    end

    return (investment=total_investment, damage=total_damage)
end

"""
    SimOptDecisions.compute_outcome(step_records, config, scenario::StochasticScenario)

Aggregate step records into final outcome with NPV discounting.
Returns (investment=..., damage=...) as discounted totals.
"""
function SimOptDecisions.compute_outcome(
    step_records::Vector,
    config::CityParameters{T},
    scenario::StochasticScenario{T}
) where {T<:Real}
    discount_rate = scenario.discount_rate

    # Sum discounted values
    total_investment = zero(T)
    total_damage = zero(T)

    for (year, record) in enumerate(step_records)
        df = SimOptDecisions.discount_factor(discount_rate, year)
        total_investment += record.investment * df
        total_damage += record.damage * df
    end

    return (investment=total_investment, damage=total_damage)
end

# ============================================================================
# Backward-compatible simulate functions (dispatch on forcing type)
# ============================================================================

"""
    simulate(city, policy, forcing::StochasticForcing; kwargs...)

Stochastic simulation mode.
Backward-compatible wrapper that calls SimOptDecisions.simulate internally.
"""
function simulate(
    city::CityParameters{T},
    policy::SimOptDecisions.AbstractPolicy,
    forcing::StochasticForcing{T};
    mode::Symbol=:scalar,
    scenario::Int=1,
    rng::AbstractRNG=Random.default_rng(),
    discount_rate::Real=0.0
) where {T<:Real}
    # Construct Scenario wrapper
    scen = StochasticScenario(forcing, scenario; discount_rate=T(discount_rate))

    if mode == :scalar
        # Use default (no recorder) for scalar mode
        result = SimOptDecisions.simulate(city, scen, policy, rng)
        return (result.investment, result.damage)
    else
        # Use TraceRecorderBuilder for trace mode
        builder = SimOptDecisions.TraceRecorderBuilder()
        result = SimOptDecisions.simulate(city, scen, policy, builder, rng)
        trace = SimOptDecisions.build_trace(builder)

        # Convert to expected format
        return (
            year = trace.times,
            W = T[s.current_levers.W for s in trace.states],
            R = T[s.current_levers.R for s in trace.states],
            P = T[s.current_levers.P for s in trace.states],
            D = T[s.current_levers.D for s in trace.states],
            B = T[s.current_levers.B for s in trace.states],
            investment = T[r.investment for r in trace.step_records],
            damage = T[r.damage for r in trace.step_records]
        )
    end
end

"""
    simulate(city, policy, forcing::DistributionalForcing; kwargs...)

Expected Annual Damage (EAD) simulation mode.
Backward-compatible wrapper that calls SimOptDecisions.simulate internally.
"""
function simulate(
    city::CityParameters{T},
    policy::SimOptDecisions.AbstractPolicy,
    forcing::DistributionalForcing{T,D};
    mode::Symbol=:scalar,
    method::Symbol=:quad,
    discount_rate::Real=0.0,
    rng::AbstractRNG=Random.default_rng(),
    kwargs...
) where {T<:Real, D<:Distribution}
    # Construct Scenario wrapper
    scen = EADScenario(forcing; discount_rate=T(discount_rate), method=method)

    if mode == :scalar
        # Use default (no recorder) for scalar mode
        result = SimOptDecisions.simulate(city, scen, policy, rng)
        return (result.investment, result.damage)
    else
        # Use TraceRecorderBuilder for trace mode
        builder = SimOptDecisions.TraceRecorderBuilder()
        result = SimOptDecisions.simulate(city, scen, policy, builder, rng)
        trace = SimOptDecisions.build_trace(builder)

        # Convert to expected format
        return (
            year = trace.times,
            W = T[s.current_levers.W for s in trace.states],
            R = T[s.current_levers.R for s in trace.states],
            P = T[s.current_levers.P for s in trace.states],
            D = T[s.current_levers.D for s in trace.states],
            B = T[s.current_levers.B for s in trace.states],
            investment = T[r.investment for r in trace.step_records],
            damage = T[r.damage for r in trace.step_records]
        )
    end
end

# ============================================================================
# Internal helper functions
# ============================================================================

"""
    _marginal_cost(city, old_levers, new_levers)

Calculate marginal investment cost (only charge for NEW infrastructure).
"""
function _marginal_cost(city::CityParameters{T}, old_levers::Levers{T}, new_levers::Levers{T}) where {T<:Real}
    cost_old = calculate_investment_cost(city, old_levers)
    cost_new = calculate_investment_cost(city, new_levers)
    return max(zero(T), cost_new - cost_old)
end
