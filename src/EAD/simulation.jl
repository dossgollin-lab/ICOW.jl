# SimOptDecisions callbacks for EAD (Expected Annual Damage) simulation

# =============================================================================
# SimOptDecisions Callbacks
# =============================================================================

"""
    SimOptDecisions.initialize(config::EADConfig, scenario, rng) -> EADState

Create initial state with zero-protection FloodDefenses.
"""
function SimOptDecisions.initialize(
    config::EADConfig{T},
    scenario::EADScenario,
    ::AbstractRNG
) where {T}
    EADState{T}()
end

"""
    SimOptDecisions.time_axis(config::EADConfig, scenario) -> UnitRange

Return simulation time axis from surge distribution vector length.
"""
function SimOptDecisions.time_axis(config::EADConfig, scenario::EADScenario)
    1:length(scenario.distributions)
end

"""
    SimOptDecisions.get_action(policy::StaticPolicy, state, t, scenario) -> StaticPolicy

Return policy at t=1 (build year), zero policy thereafter.
"""
function SimOptDecisions.get_action(
    policy::StaticPolicy{Tp},
    state::EADState,
    t::SimOptDecisions.TimeStep,
    scenario::EADScenario
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
    SimOptDecisions.run_timestep(state, action, t, config::EADConfig, scenario, rng) -> (state, record)

Execute one year: convert policy to defenses, enforce irreversibility, compute investment and expected damage.
"""
function SimOptDecisions.run_timestep(
    state::EADState{T},
    action::StaticPolicy,
    t::SimOptDecisions.TimeStep,
    config::EADConfig{T},
    scenario::EADScenario,
    rng::AbstractRNG
) where {T}
    year = SimOptDecisions.index(t)

    # Convert policy fractions to FloodDefenses
    action_defenses = FloodDefenses(action, config)

    # Enforce irreversibility
    new_defenses = max(state.defenses, action_defenses)

    # Check feasibility - return infinite costs if infeasible
    if !is_feasible(new_defenses, config)
        new_state = EADState(new_defenses)
        record = (investment=T(Inf), expected_damage=T(Inf), W=new_defenses.W, R=new_defenses.R,
                  P=new_defenses.P, D=new_defenses.D, B=new_defenses.B)
        return (new_state, record)
    end

    # Marginal investment cost (only pay for increases)
    cost = _investment_cost(config, new_defenses) - _investment_cost(config, state.defenses)
    cost = max(zero(T), cost)

    # Expected damage via integration over surge distribution
    dist = scenario.distributions[year]
    expected_dmg = _integrate_expected_damage(scenario.integrator, config, new_defenses, dist, rng)

    # Update state
    new_state = EADState(new_defenses)

    # Step record with defense values for tracing
    record = (investment=cost, expected_damage=expected_dmg, W=new_defenses.W, R=new_defenses.R,
              P=new_defenses.P, D=new_defenses.D, B=new_defenses.B)

    return (new_state, record)
end

"""
    SimOptDecisions.compute_outcome(step_records, config::EADConfig, scenario) -> EADOutcome

Aggregate step records into discounted investment and expected damage totals.
"""
function SimOptDecisions.compute_outcome(
    step_records::Vector,
    config::EADConfig{T},
    scenario::EADScenario
) where {T}
    r = scenario.discount_rate
    total_investment = zero(T)
    total_expected_damage = zero(T)

    for (year, record) in enumerate(step_records)
        # End-of-year discounting: costs at year t are discounted by 1/(1+r)^t
        df = one(T) / (one(T) + r)^year
        total_investment += record.investment * df
        total_expected_damage += record.expected_damage * df
    end

    EADOutcome(investment=total_investment, expected_damage=total_expected_damage)
end

# =============================================================================
# Helper Functions
# =============================================================================

"""
    _investment_cost(config::EADConfig, fd::FloodDefenses) -> cost

Calculate total investment cost (withdrawal + resistance + dike) for given defenses.
"""
function _investment_cost(config::EADConfig{T}, fd::FloodDefenses{T}) where {T}
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
    _expected_damage_for_surge(config::EADConfig{T}, fd::FloodDefenses{T}, h_raw::T) -> T

Calculate expected damage for a single surge height, integrating over dike failure probability.
"""
function _expected_damage_for_surge(config::EADConfig{T}, fd::FloodDefenses{T}, h_raw::T) where {T}
    V_w = Core.value_after_withdrawal(config.V_city, config.H_city, config.f_l, fd.W)
    bounds = Core.zone_boundaries(config.H_city, fd.W, fd.R, fd.B, fd.D)
    values = Core.zone_values(V_w, config.H_city, fd.W, fd.R, fd.B, fd.D, config.r_prot, config.r_unprot)

    return Core.expected_damage_given_surge(
        h_raw, bounds, values,
        config.H_seawall, config.f_runup, fd.W, fd.B, fd.D, config.t_fail, config.p_min,
        config.b_basement, config.H_bldg, config.f_damage, fd.P, config.f_intact, config.f_failed,
        config.d_thresh, config.f_thresh, config.gamma_thresh
    )
end

# =============================================================================
# Integration Methods
# =============================================================================

"""
    _integrate_expected_damage(integrator::QuadratureIntegrator, config, fd, dist, rng) -> T

Compute expected annual damage using adaptive quadrature.
Integrates expected_damage_given_surge weighted by the PDF over the surge distribution.
"""
function _integrate_expected_damage(
    integrator::QuadratureIntegrator{Ti},
    config::EADConfig{T},
    fd::FloodDefenses{T},
    dist::D,
    ::AbstractRNG
) where {Ti, T, D<:Distribution}
    # Handle Dirac (point mass) distributions specially
    if dist isa Distributions.Dirac
        h = dist.value
        return _expected_damage_for_surge(config, fd, T(h))
    end

    # Integration bounds from distribution quantiles (avoid infinite bounds)
    h_min = T(quantile(dist, 0.0001))
    h_max = T(quantile(dist, 0.9999))

    # Integrand: pdf(h) * expected_damage(h)
    integrand = h -> begin
        h_T = T(h)
        pdf_val = pdf(dist, h_T)
        dmg = _expected_damage_for_surge(config, fd, h_T)
        pdf_val * dmg
    end

    result, _ = quadgk(integrand, h_min, h_max; rtol=integrator.rtol)
    return T(result)
end

"""
    _integrate_expected_damage(integrator::MonteCarloIntegrator, config, fd, dist, rng) -> T

Compute expected annual damage using Monte Carlo sampling.
"""
function _integrate_expected_damage(
    integrator::MonteCarloIntegrator,
    config::EADConfig{T},
    fd::FloodDefenses{T},
    dist::D,
    rng::AbstractRNG
) where {T, D<:Distribution}
    total_damage = zero(T)

    for _ in 1:integrator.n_samples
        h_raw = T(rand(rng, dist))
        total_damage += _expected_damage_for_surge(config, fd, h_raw)
    end

    return total_damage / integrator.n_samples
end
