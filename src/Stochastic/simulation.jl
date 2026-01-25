# SimOptDecisions callbacks for stochastic simulation

# =============================================================================
# SimOptDecisions Callbacks
# =============================================================================

"""Initialize state at start of simulation."""
function SimOptDecisions.initialize(
    config::StochasticConfig{T},
    scenario::StochasticScenario,
    ::AbstractRNG
) where {T}
    StochasticState{T}()
end

"""Return time axis (years)."""
function SimOptDecisions.time_axis(config::StochasticConfig, scenario::StochasticScenario)
    1:length(SimOptDecisions.value(scenario.surges))
end

"""Get action from policy given current state."""
function SimOptDecisions.get_action(
    policy::StaticPolicy,
    state::StochasticState{T},
    t::SimOptDecisions.TimeStep,
    scenario::StochasticScenario
) where {T}
    # Static policy: return policy in year 1, zero policy otherwise
    # Conversion to FloodDefenses happens in run_timestep (which has config)
    if SimOptDecisions.index(t) == 1
        policy
    else
        # Return a zero policy
        StaticPolicy(a_frac=zero(T), w_frac=zero(T), b_frac=zero(T), r_frac=zero(T), P=zero(T))
    end
end

"""Execute one timestep: apply action, compute costs and damage."""
function SimOptDecisions.run_timestep(
    state::StochasticState{T},
    action::StaticPolicy,
    t::SimOptDecisions.TimeStep,
    config::StochasticConfig{T},
    scenario::StochasticScenario,
    rng::AbstractRNG
) where {T}
    year = SimOptDecisions.index(t)

    # Convert policy fractions to FloodDefenses
    action_defenses = FloodDefenses(action, config)

    # Enforce irreversibility
    new_defenses = max(state.defenses, action_defenses)

    # Check feasibility - return infinite costs if infeasible
    if !is_feasible(new_defenses, config)
        new_state = StochasticState(new_defenses)
        record = (investment=T(Inf), damage=T(Inf), W=new_defenses.W, R=new_defenses.R,
                  P=new_defenses.P, D=new_defenses.D, B=new_defenses.B)
        return (new_state, record)
    end

    # Marginal investment cost (only pay for increases)
    cost = _investment_cost(config, new_defenses) - _investment_cost(config, state.defenses)
    cost = max(zero(T), cost)

    # Stochastic damage
    surges = SimOptDecisions.value(scenario.surges)
    h_raw = surges[year]
    damage = _stochastic_damage(config, new_defenses, h_raw, rng)

    # Update state
    new_state = StochasticState(new_defenses)

    # Step record with defense values for tracing
    record = (investment=cost, damage=damage, W=new_defenses.W, R=new_defenses.R,
              P=new_defenses.P, D=new_defenses.D, B=new_defenses.B)

    return (new_state, record)
end

"""Aggregate step records into final outcome."""
function SimOptDecisions.compute_outcome(
    step_records::Vector,
    config::StochasticConfig{T},
    scenario::StochasticScenario
) where {T}
    r = SimOptDecisions.value(scenario.discount_rate)
    total_investment = zero(T)
    total_damage = zero(T)

    for (year, record) in enumerate(step_records)
        df = one(T) / (one(T) + r)^year
        total_investment += record.investment * df
        total_damage += record.damage * df
    end

    StochasticOutcome(investment=total_investment, damage=total_damage)
end

# =============================================================================
# Helper Functions
# =============================================================================

"""Calculate total investment cost for given defenses."""
function _investment_cost(config::StochasticConfig{T}, fd::FloodDefenses{T}) where {T}
    # W < H_city required by Core.withdrawal_cost (division by H_city - W)
    @assert fd.W < config.H_city "W must be strictly less than H_city"

    C_W = Core.withdrawal_cost(config.V_city, config.H_city, config.f_w, fd.W)

    V_w = Core.value_after_withdrawal(config.V_city, config.H_city, config.f_l, fd.W)
    f_cR = Core.resistance_cost_fraction(config.f_adj, config.f_lin, config.f_exp, config.t_exp, fd.P)
    C_R = Core.resistance_cost(V_w, f_cR, config.H_bldg, config.H_city, fd.W, fd.R, fd.B, config.b_basement)

    if fd.D == zero(T)
        C_D = zero(T)
    else
        V_d = Core.dike_volume(config.H_city, config.D_city, config.D_startup, config.s_dike, config.w_d, config.W_city, fd.D)
        C_D = Core.dike_cost(V_d, config.c_d)
    end

    return C_W + C_R + C_D
end

"""Calculate stochastic damage with sampled dike failure."""
function _stochastic_damage(
    config::StochasticConfig{T},
    fd::FloodDefenses{T},
    h_raw::T,
    rng::AbstractRNG
) where {T}
    h_eff = Core.effective_surge(h_raw, config.H_seawall, config.f_runup)

    # Dike failure probability
    dike_base = fd.W + fd.B
    h_at_dike = max(zero(T), h_eff - dike_base)
    p_fail = Core.dike_failure_probability(h_at_dike, fd.D, config.t_fail, config.p_min)
    dike_failed = rand(rng) < p_fail

    # Zone data
    V_w = Core.value_after_withdrawal(config.V_city, config.H_city, config.f_l, fd.W)
    bounds = Core.zone_boundaries(config.H_city, fd.W, fd.R, fd.B, fd.D)
    values = Core.zone_values(V_w, config.H_city, fd.W, fd.R, fd.B, fd.D, config.r_prot, config.r_unprot)

    return Core.total_event_damage(
        bounds, values, h_eff,
        config.b_basement, config.H_bldg, config.f_damage, fd.P, config.f_intact, config.f_failed,
        config.d_thresh, config.f_thresh, config.gamma_thresh, dike_failed
    )
end
