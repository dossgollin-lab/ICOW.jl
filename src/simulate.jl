# Simple stochastic simulation

"""
    simulate(config, scenario, policy; rng=default_rng()) -> Outcome

Run stochastic simulation with pre-sampled surges.
"""
function simulate(
    config::Config,
    scenario::Scenario,
    policy::Policy;
    rng::AbstractRNG=Random.default_rng()
)
    city = config.city
    n = length(scenario.surges)
    r = scenario.discount_rate

    # Initialize state
    state = State()

    total_investment = 0.0
    total_damage = 0.0

    for year in 1:n
        # Get action (year 1 only for static policy)
        action = year == 1 ? policy.levers : Levers(0.0, 0.0, 0.0, 0.0, 0.0)

        # Enforce irreversibility
        new_levers = max(state.levers, action)

        # Check feasibility
        if !Core.is_feasible(new_levers, city)
            return Outcome(Inf, Inf)
        end

        # Marginal investment cost
        cost = _investment_cost(city, new_levers) - _investment_cost(city, state.levers)
        cost = max(0.0, cost)

        # Stochastic damage
        h_raw = scenario.surges[year]
        damage = _stochastic_damage(city, new_levers, h_raw, rng)

        # Discount and accumulate
        df = 1.0 / (1.0 + r)^year
        total_investment += cost * df
        total_damage += damage * df

        # Update state
        state.levers = new_levers
    end

    return Outcome(total_investment, total_damage)
end

# Investment cost using Core functions
function _investment_cost(city::CityParameters, levers::Levers)
    C_W = Core.withdrawal_cost(city.V_city, city.H_city, city.f_w, levers.W)

    V_w = Core.value_after_withdrawal(city.V_city, city.H_city, city.f_l, levers.W)
    f_cR = Core.resistance_cost_fraction(city.f_adj, city.f_lin, city.f_exp, city.t_exp, levers.P)
    C_R = Core.resistance_cost(V_w, f_cR, city.H_bldg, city.H_city, levers.W, levers.R, levers.B, city.b_basement)

    if levers.D == 0.0
        C_D = 0.0
    else
        V_d = Core.dike_volume(city.H_city, city.D_city, city.D_startup, city.s_dike, city.w_d, city.W_city, levers.D)
        C_D = Core.dike_cost(V_d, city.c_d)
    end

    return C_W + C_R + C_D
end

# Stochastic damage with sampled dike failure
function _stochastic_damage(city::CityParameters, levers::Levers, h_raw::Float64, rng::AbstractRNG)
    h_eff = Core.effective_surge(h_raw, city.H_seawall, city.f_runup)

    # Dike failure
    dike_base = levers.W + levers.B
    h_at_dike = max(0.0, h_eff - dike_base)
    p_fail = Core.dike_failure_probability(h_at_dike, levers.D, city.t_fail, city.p_min)
    dike_failed = rand(rng) < p_fail

    # Zone data
    V_w = Core.value_after_withdrawal(city.V_city, city.H_city, city.f_l, levers.W)
    bounds = Core.zone_boundaries(city.H_city, levers.W, levers.R, levers.B, levers.D)
    values = Core.zone_values(V_w, city.H_city, levers.W, levers.R, levers.B, levers.D, city.r_prot, city.r_unprot)

    return Core.total_event_damage(
        bounds, values, h_eff,
        city.b_basement, city.H_bldg, city.f_damage, levers.P, city.f_intact, city.f_failed,
        city.d_thresh, city.f_thresh, city.gamma_thresh, dike_failed
    )
end
