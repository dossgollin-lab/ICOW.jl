# SimOptDecisions callbacks for stochastic simulation

# =============================================================================
# SimOptDecisions Callbacks
# =============================================================================

"""
    SimOptDecisions.initialize(config::StochasticConfig, scenario, rng) -> StochasticState

Create initial state with zero-protection FloodDefenses.
"""
function SimOptDecisions.initialize(
    config::StochasticConfig{T},
    scenario::StochasticScenario,
    ::AbstractRNG
) where {T}
    StochasticState{T}()
end

"""
    SimOptDecisions.time_axis(config::StochasticConfig, scenario) -> UnitRange

Return simulation time axis from surge time series length.
"""
function SimOptDecisions.time_axis(config::StochasticConfig, scenario::StochasticScenario)
    1:length(SimOptDecisions.value(scenario.surges))
end

"""
    SimOptDecisions.get_action(policy::StaticPolicy, state, t, scenario) -> StaticPolicy

Return policy at t=1 (build year), zero policy thereafter.
"""
function SimOptDecisions.get_action(
    policy::StaticPolicy{Tp},
    state::StochasticState,
    t::SimOptDecisions.TimeStep,
    scenario::StochasticScenario
) where {Tp}
    # Static policy: return policy in year 1, zero policy otherwise
    # Conversion to FloodDefenses happens in run_timestep (which has config)
    if SimOptDecisions.index(t) == 1
        policy
    else
        # Return a zero policy (type from policy, not state, for type stability)
        StaticPolicy(a_frac=zero(Tp), w_frac=zero(Tp), b_frac=zero(Tp), r_frac=zero(Tp), P=zero(Tp))
    end
end

"""
    SimOptDecisions.run_timestep(state, action, t, config::StochasticConfig, scenario, rng) -> (state, record)

Execute one year: convert policy to defenses, enforce irreversibility, compute investment and stochastic damage.
"""
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

"""
    SimOptDecisions.compute_outcome(step_records, config::StochasticConfig, scenario) -> StochasticOutcome

Aggregate step records into discounted investment and damage totals.
"""
function SimOptDecisions.compute_outcome(
    step_records::Vector,
    config::StochasticConfig{T},
    scenario::StochasticScenario
) where {T}
    r = SimOptDecisions.value(scenario.discount_rate)
    total_investment = zero(T)
    total_damage = zero(T)

    for (year, record) in enumerate(step_records)
        # End-of-year discounting: costs at year t are discounted by 1/(1+r)^t
        df = one(T) / (one(T) + r)^year
        total_investment += record.investment * df
        total_damage += record.damage * df
    end

    StochasticOutcome(investment=total_investment, damage=total_damage)
end

# =============================================================================
# Helper Functions
# =============================================================================

"""
    _investment_cost(config::StochasticConfig, fd::FloodDefenses) -> cost

Calculate total investment cost (withdrawal + resistance + dike) for given defenses.
"""
function _investment_cost(config::StochasticConfig{T}, fd::FloodDefenses{T}) where {T}
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

"""
    _stochastic_damage(config::StochasticConfig, fd::FloodDefenses, h_raw, rng) -> damage

Calculate realized damage for a single surge with sampled dike failure (Bernoulli draw).
"""
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
