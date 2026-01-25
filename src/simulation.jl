# SimOptDecisions integration for ICOW
# Implements the simulation interface via method dispatch

# =============================================================================
# SimOptDecisions Methods
# =============================================================================

"""Initialize state at start of simulation."""
function SimOptDecisions.initialize(
    config::Config{T},
    scenario::Scenario{T},
    ::AbstractRNG
) where {T}
    State(FloodDefenses{T}(zero(T), zero(T), zero(T), zero(T), zero(T)))
end

"""Return time axis (years)."""
function SimOptDecisions.time_axis(config::Config, scenario::Scenario)
    1:length(scenario.surges)
end

"""Get action from policy given current state."""
function SimOptDecisions.get_action(
    policy::StaticPolicy{T},
    state::State{T},
    t::SimOptDecisions.TimeStep,
    scenario::Scenario{T}
) where {T}
    # Static policy: apply target defenses in year 1 only
    if SimOptDecisions.index(t) == 1
        defenses(policy)
    else
        FloodDefenses{T}(zero(T), zero(T), zero(T), zero(T), zero(T))
    end
end

"""Execute one timestep: apply action, compute costs and damage."""
function SimOptDecisions.run_timestep(
    state::State{T},
    action::FloodDefenses{T},
    t::SimOptDecisions.TimeStep,
    config::Config{T},
    scenario::Scenario{T},
    rng::AbstractRNG
) where {T}
    city = config.city
    year = SimOptDecisions.index(t)

    # Enforce irreversibility
    new_defenses = max(state.defenses, action)

    # Check feasibility - return infinite costs if infeasible
    if !is_feasible(new_defenses, city)
        new_state = State(new_defenses)
        return (new_state, StepRecord{T}(T(Inf), T(Inf)))
    end

    # Marginal investment cost (only pay for increases)
    cost = _investment_cost(city, new_defenses) - _investment_cost(city, state.defenses)
    cost = max(zero(T), cost)

    # Stochastic damage
    h_raw = scenario.surges[year]
    damage = _stochastic_damage(city, new_defenses, h_raw, rng)

    # Update state
    new_state = State(new_defenses)

    return (new_state, StepRecord{T}(cost, damage))
end

"""Aggregate step records into final outcome."""
function SimOptDecisions.compute_outcome(
    step_records::Vector{StepRecord{T}},
    config::Config{T},
    scenario::Scenario{T}
) where {T}
    r = scenario.discount_rate
    total_investment = zero(T)
    total_damage = zero(T)

    for (year, record) in enumerate(step_records)
        df = one(T) / (one(T) + r)^year
        total_investment += record.investment * df
        total_damage += record.damage * df
    end

    Outcome{T}(total_investment, total_damage)
end

# =============================================================================
# Helper Functions (internal)
# =============================================================================

"""Calculate total investment cost for given defenses."""
function _investment_cost(city::CityParameters{T}, fd::FloodDefenses{T}) where {T}
    C_W = Core.withdrawal_cost(city.V_city, city.H_city, city.f_w, fd.W)

    V_w = Core.value_after_withdrawal(city.V_city, city.H_city, city.f_l, fd.W)
    f_cR = Core.resistance_cost_fraction(city.f_adj, city.f_lin, city.f_exp, city.t_exp, fd.P)
    C_R = Core.resistance_cost(V_w, f_cR, city.H_bldg, city.H_city, fd.W, fd.R, fd.B, city.b_basement)

    if fd.D == zero(T)
        C_D = zero(T)
    else
        V_d = Core.dike_volume(city.H_city, city.D_city, city.D_startup, city.s_dike, city.w_d, city.W_city, fd.D)
        C_D = Core.dike_cost(V_d, city.c_d)
    end

    return C_W + C_R + C_D
end

"""Calculate stochastic damage with sampled dike failure."""
function _stochastic_damage(
    city::CityParameters{T},
    fd::FloodDefenses{T},
    h_raw::T,
    rng::AbstractRNG
) where {T}
    h_eff = Core.effective_surge(h_raw, city.H_seawall, city.f_runup)

    # Dike failure probability
    dike_base = fd.W + fd.B
    h_at_dike = max(zero(T), h_eff - dike_base)
    p_fail = Core.dike_failure_probability(h_at_dike, fd.D, city.t_fail, city.p_min)
    dike_failed = rand(rng) < p_fail

    # Zone data
    V_w = Core.value_after_withdrawal(city.V_city, city.H_city, city.f_l, fd.W)
    bounds = Core.zone_boundaries(city.H_city, fd.W, fd.R, fd.B, fd.D)
    values = Core.zone_values(V_w, city.H_city, fd.W, fd.R, fd.B, fd.D, city.r_prot, city.r_unprot)

    return Core.total_event_damage(
        bounds, values, h_eff,
        city.b_basement, city.H_bldg, city.f_damage, fd.P, city.f_intact, city.f_failed,
        city.d_thresh, city.f_thresh, city.gamma_thresh, dike_failed
    )
end
