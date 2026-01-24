# SimOptDecisions five-callback implementation for ICOW
# Callbacks: initialize, time_axis, get_action, run_timestep, compute_outcome

using Random

# ============================================================================
# Callback 1: initialize
# ============================================================================

"""Create initial state with zero levers."""
function SimOptDecisions.initialize(
    config::ICOWConfig{T}, scenario::Union{EADScenario,StochasticScenario}, rng::AbstractRNG
) where {T}
    return ICOWState{T}()
end

# ============================================================================
# Callback 2: time_axis
# ============================================================================

"""Return time points (years) for simulation."""
function SimOptDecisions.time_axis(config::ICOWConfig, scenario::Union{EADScenario,StochasticScenario})
    return 1:n_years(scenario)
end

# ============================================================================
# Callback 3: get_action
# ============================================================================

"""StaticPolicy returns fixed levers in year 1, zero otherwise."""
function SimOptDecisions.get_action(
    policy::StaticPolicy{T}, state::ICOWState, t::SimOptDecisions.TimeStep, scenario::Union{EADScenario,StochasticScenario}
) where {T}
    if t.t == 1
        return policy.levers
    else
        return Core.Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T))
    end
end

# ============================================================================
# Callback 4: run_timestep
# ============================================================================

"""Execute one timestep: enforce irreversibility, calculate costs and damage."""
function SimOptDecisions.run_timestep(
    state::ICOWState{T},
    action::Core.Levers{T},
    t::SimOptDecisions.TimeStep,
    config::ICOWConfig{T},
    scenario::EADScenario{T},
    rng::AbstractRNG
) where {T}
    city = config.city
    year = t.t

    # Enforce irreversibility: can only increase protection
    new_levers = max(state.current_levers, action)

    # Check feasibility - return Inf costs for infeasible levers
    if !Core.is_feasible(new_levers, city)
        step_record = (
            W=new_levers.W, R=new_levers.R, P=new_levers.P, D=new_levers.D, B=new_levers.B,
            investment=T(Inf), damage=T(Inf), feasible=false
        )
        state.current_levers = new_levers
        state.current_year = year + 1
        return (state, step_record)
    end

    # Calculate marginal investment cost using Core functions
    cost = _marginal_investment_cost(city, state.current_levers, new_levers)

    # Calculate EAD damage
    damage = _calculate_ead_damage(city, new_levers, scenario, year)

    # Update state
    state.current_levers = new_levers
    state.current_year = year + 1

    step_record = (
        W=new_levers.W, R=new_levers.R, P=new_levers.P, D=new_levers.D, B=new_levers.B,
        investment=cost, damage=damage, feasible=true
    )

    return (state, step_record)
end

"""Execute one timestep for stochastic scenario."""
function SimOptDecisions.run_timestep(
    state::ICOWState{T},
    action::Core.Levers{T},
    t::SimOptDecisions.TimeStep,
    config::ICOWConfig{T},
    scenario::StochasticScenario{T},
    rng::AbstractRNG
) where {T}
    city = config.city
    year = t.t

    # Enforce irreversibility
    new_levers = max(state.current_levers, action)

    # Check feasibility
    if !Core.is_feasible(new_levers, city)
        step_record = (
            W=new_levers.W, R=new_levers.R, P=new_levers.P, D=new_levers.D, B=new_levers.B,
            investment=T(Inf), damage=T(Inf), feasible=false
        )
        state.current_levers = new_levers
        state.current_year = year + 1
        return (state, step_record)
    end

    # Calculate marginal investment cost
    cost = _marginal_investment_cost(city, state.current_levers, new_levers)

    # Calculate stochastic damage
    h_raw = get_surge(scenario, year)
    damage = _calculate_stochastic_damage(city, new_levers, h_raw, rng)

    # Update state
    state.current_levers = new_levers
    state.current_year = year + 1

    step_record = (
        W=new_levers.W, R=new_levers.R, P=new_levers.P, D=new_levers.D, B=new_levers.B,
        investment=cost, damage=damage, feasible=true
    )

    return (state, step_record)
end

# ============================================================================
# Callback 5: compute_outcome
# ============================================================================

"""Aggregate step records into total discounted investment and damage."""
function SimOptDecisions.compute_outcome(
    step_records::Vector,
    config::ICOWConfig{T},
    scenario::Union{EADScenario{T},StochasticScenario{T}}
) where {T}
    discount_rate = scenario.discount_rate

    total_investment = zero(T)
    total_damage = zero(T)

    for (i, record) in enumerate(step_records)
        discount_factor = one(T) / (one(T) + discount_rate)^i
        total_investment += record.investment * discount_factor
        total_damage += record.damage * discount_factor
    end

    return ICOWOutcome{T}(total_investment, total_damage)
end

# ============================================================================
# Internal helper functions (use Core pure numeric functions)
# ============================================================================

"""Calculate marginal investment cost (new infrastructure only)."""
function _marginal_investment_cost(
    city::Core.CityParameters{T},
    old_levers::Core.Levers{T},
    new_levers::Core.Levers{T}
) where {T}
    cost_old = _total_investment_cost(city, old_levers)
    cost_new = _total_investment_cost(city, new_levers)
    return max(zero(T), cost_new - cost_old)
end

"""Calculate total investment cost using Core functions."""
function _total_investment_cost(city::Core.CityParameters{T}, levers::Core.Levers{T}) where {T}
    # Withdrawal cost
    C_W = Core.withdrawal_cost(city.V_city, city.H_city, city.f_w, levers.W)

    # Resistance cost
    V_w = Core.value_after_withdrawal(city.V_city, city.H_city, city.f_l, levers.W)
    f_cR = Core.resistance_cost_fraction(city.f_adj, city.f_lin, city.f_exp, city.t_exp, levers.P)
    C_R = Core.resistance_cost(V_w, f_cR, city.H_bldg, city.H_city, levers.W, levers.R, levers.B, city.b_basement)

    # Dike cost
    if levers.D == zero(T)
        C_D = zero(T)
    else
        V_dike = Core.dike_volume(city.H_city, city.D_city, city.D_startup, city.s_dike, city.w_d, city.W_city, levers.D)
        C_D = Core.dike_cost(V_dike, city.c_d)
    end

    return C_W + C_R + C_D
end

"""Calculate EAD damage using quadrature or Monte Carlo."""
function _calculate_ead_damage(
    city::Core.CityParameters{T},
    levers::Core.Levers{T},
    scenario::EADScenario{T},
    year::Int
) where {T}
    dist = get_distribution(scenario, year)

    if scenario.method == :mc
        return _ead_monte_carlo(city, levers, dist)
    else
        return _ead_quadrature(city, levers, dist)
    end
end

"""Monte Carlo EAD integration."""
function _ead_monte_carlo(
    city::Core.CityParameters{T},
    levers::Core.Levers{T},
    dist::Distribution;
    n_samples::Int=1000
) where {T}
    rng = Random.default_rng()
    total = zero(T)

    for _ in 1:n_samples
        h_raw = rand(rng, dist)
        total += _expected_damage_given_surge(city, levers, h_raw)
    end

    return total / n_samples
end

"""Quadrature EAD integration."""
function _ead_quadrature(
    city::Core.CityParameters{T},
    levers::Core.Levers{T},
    dist::Distribution;
    rtol::Real=1e-6
) where {T}
    # Handle Dirac (deterministic) distributions
    if dist isa Dirac
        return _expected_damage_given_surge(city, levers, dist.value)
    end

    integrand(h) = pdf(dist, h) * _expected_damage_given_surge(city, levers, h)
    result, _ = quadgk(integrand, -Inf, Inf; rtol=rtol)
    return result
end

"""Calculate expected damage given surge height (integrates over dike failure)."""
function _expected_damage_given_surge(
    city::Core.CityParameters{T},
    levers::Core.Levers{T},
    h_raw::Real
) where {T}
    # Precompute zone data
    V_w = Core.value_after_withdrawal(city.V_city, city.H_city, city.f_l, levers.W)
    bounds = Core.zone_boundaries(city.H_city, levers.W, levers.R, levers.B, levers.D)
    values = Core.zone_values(V_w, city.H_city, levers.W, levers.R, levers.B, levers.D, city.r_prot, city.r_unprot)

    return Core.expected_damage_given_surge(
        T(h_raw), bounds, values,
        city.H_seawall, city.f_runup, levers.W, levers.B, levers.D, city.t_fail, city.p_min,
        city.b_basement, city.H_bldg, city.f_damage, levers.P, city.f_intact, city.f_failed,
        city.d_thresh, city.f_thresh, city.gamma_thresh
    )
end

"""Calculate stochastic damage with sampled dike failure."""
function _calculate_stochastic_damage(
    city::Core.CityParameters{T},
    levers::Core.Levers{T},
    h_raw::Real,
    rng::AbstractRNG
) where {T}
    # Effective surge
    h_eff = Core.effective_surge(T(h_raw), city.H_seawall, city.f_runup)

    # Dike failure probability
    dike_base = levers.W + levers.B
    h_at_dike = max(zero(T), h_eff - dike_base)
    p_fail = Core.dike_failure_probability(h_at_dike, levers.D, city.t_fail, city.p_min)

    # Sample dike failure
    dike_failed = rand(rng) < p_fail

    # Compute zone data
    V_w = Core.value_after_withdrawal(city.V_city, city.H_city, city.f_l, levers.W)
    bounds = Core.zone_boundaries(city.H_city, levers.W, levers.R, levers.B, levers.D)
    values = Core.zone_values(V_w, city.H_city, levers.W, levers.R, levers.B, levers.D, city.r_prot, city.r_unprot)

    return Core.total_event_damage(
        bounds, values, h_eff,
        city.b_basement, city.H_bldg, city.f_damage, levers.P, city.f_intact, city.f_failed,
        city.d_thresh, city.f_thresh, city.gamma_thresh, dike_failed
    )
end
