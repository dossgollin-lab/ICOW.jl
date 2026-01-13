# Simulation engine for the iCOW model
# Time-stepping loop with dual-mode support (stochastic and EAD)

using Random

# ============================================================================
# SimOptDecisions interface: simulate methods
# ============================================================================

"""
    SimOptDecisions.simulate(config, sow::EADSOW, policy, recorder, rng)

EAD (Expected Annual Damage) simulation using SimOptDecisions interface.
Returns NamedTuple: `(investment=..., damage=...)` with discounted totals.
"""
function SimOptDecisions.simulate(
    config::CityParameters{T},
    sow::EADSOW{T,D},
    policy::SimOptDecisions.AbstractPolicy,
    recorder::SimOptDecisions.AbstractRecorder,
    rng::AbstractRNG,
) where {T<:Real, D<:Distribution}
    n = n_years(sow)
    discount_rate = sow.discount_rate

    # Initialize state
    state = State(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)))
    SimOptDecisions.record!(recorder, state, nothing, nothing, nothing)

    # Accumulators
    accumulated_cost = zero(T)
    accumulated_damage = zero(T)

    # Main time-stepping loop
    for ts in SimOptDecisions.Utils.timeindex(1:n)
        year = ts.val

        # Get action from policy
        target = SimOptDecisions.get_action(policy, state, sow, ts)

        # Enforce irreversibility: can only increase protection
        new_levers = max(state.current_levers, target)

        # Validate feasibility (return Inf for infeasible levers during optimization)
        if !is_feasible(new_levers, config)
            return (investment=T(Inf), damage=T(Inf))
        end

        # Calculate marginal investment cost
        cost = _marginal_cost(config, state.current_levers, new_levers)

        # Calculate EAD damage
        damage = calculate_expected_damage(config, new_levers, sow.forcing, year; method=sow.method)

        # Apply discounting
        discount_factor = one(T) / (one(T) + discount_rate)^year
        accumulated_cost += cost * discount_factor
        accumulated_damage += damage * discount_factor

        # Update state
        state.current_levers = new_levers
        state.current_year = year + 1

        # Record step
        step_record = (
            W=new_levers.W, R=new_levers.R, P=new_levers.P, D=new_levers.D, B=new_levers.B,
            investment=cost, damage=damage
        )
        SimOptDecisions.record!(recorder, state, step_record, year, new_levers)
    end

    return (investment=accumulated_cost, damage=accumulated_damage)
end

"""
    SimOptDecisions.simulate(config, sow::StochasticSOW, policy, recorder, rng)

Stochastic simulation using SimOptDecisions interface.
Returns NamedTuple: `(investment=..., damage=...)` with discounted totals.
"""
function SimOptDecisions.simulate(
    config::CityParameters{T},
    sow::StochasticSOW{T},
    policy::SimOptDecisions.AbstractPolicy,
    recorder::SimOptDecisions.AbstractRecorder,
    rng::AbstractRNG,
) where {T<:Real}
    n = n_years(sow)
    discount_rate = sow.discount_rate

    # Initialize state
    state = State(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)))
    SimOptDecisions.record!(recorder, state, nothing, nothing, nothing)

    # Accumulators
    accumulated_cost = zero(T)
    accumulated_damage = zero(T)

    # Main time-stepping loop
    for ts in SimOptDecisions.Utils.timeindex(1:n)
        year = ts.val

        # Get action from policy
        target = SimOptDecisions.get_action(policy, state, sow, ts)

        # Enforce irreversibility: can only increase protection
        new_levers = max(state.current_levers, target)

        # Validate feasibility (return Inf for infeasible levers during optimization)
        if !is_feasible(new_levers, config)
            return (investment=T(Inf), damage=T(Inf))
        end

        # Calculate marginal investment cost
        cost = _marginal_cost(config, state.current_levers, new_levers)

        # Calculate stochastic damage
        h_raw = get_surge(sow, year)
        damage = calculate_event_damage_stochastic(h_raw, config, new_levers, rng)

        # Apply discounting
        discount_factor = one(T) / (one(T) + discount_rate)^year
        accumulated_cost += cost * discount_factor
        accumulated_damage += damage * discount_factor

        # Update state
        state.current_levers = new_levers
        state.current_year = year + 1

        # Record step
        step_record = (
            W=new_levers.W, R=new_levers.R, P=new_levers.P, D=new_levers.D, B=new_levers.B,
            investment=cost, damage=damage
        )
        SimOptDecisions.record!(recorder, state, step_record, year, new_levers)
    end

    return (investment=accumulated_cost, damage=accumulated_damage)
end

# ============================================================================
# Backward-compatible simulate functions (dispatch on forcing type)
# ============================================================================

"""
    simulate(city, policy, forcing::StochasticForcing; kwargs...)

Stochastic simulation mode. See docs/equations.md.
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
    # Construct SOW wrapper
    sow = StochasticSOW(forcing, scenario; discount_rate=T(discount_rate))

    if mode == :scalar
        # Use NoRecorder for scalar mode
        result = SimOptDecisions.simulate(city, sow, policy, SimOptDecisions.NoRecorder(), rng)
        return (result.investment, result.damage)
    else
        # Use TraceRecorderBuilder for trace mode
        builder = SimOptDecisions.TraceRecorderBuilder()
        result = SimOptDecisions.simulate(city, sow, policy, builder, rng)
        trace = SimOptDecisions.build_trace(builder)

        # Convert to expected format (year, W, R, P, D, B, investment, damage vectors)
        return (
            year = trace.times,
            W = T[r.W for r in trace.step_records],
            R = T[r.R for r in trace.step_records],
            P = T[r.P for r in trace.step_records],
            D = T[r.D for r in trace.step_records],
            B = T[r.B for r in trace.step_records],
            investment = T[r.investment for r in trace.step_records],
            damage = T[r.damage for r in trace.step_records]
        )
    end
end

"""
    simulate(city, policy, forcing::DistributionalForcing; kwargs...)

Expected Annual Damage (EAD) simulation mode. See docs/equations.md.
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
    # Construct SOW wrapper
    sow = EADSOW(forcing; discount_rate=T(discount_rate), method=method)

    if mode == :scalar
        # Use NoRecorder for scalar mode
        result = SimOptDecisions.simulate(city, sow, policy, SimOptDecisions.NoRecorder(), rng)
        return (result.investment, result.damage)
    else
        # Use TraceRecorderBuilder for trace mode
        builder = SimOptDecisions.TraceRecorderBuilder()
        result = SimOptDecisions.simulate(city, sow, policy, builder, rng)
        trace = SimOptDecisions.build_trace(builder)

        # Convert to expected format (year, W, R, P, D, B, investment, damage vectors)
        return (
            year = trace.times,
            W = T[r.W for r in trace.step_records],
            R = T[r.R for r in trace.step_records],
            P = T[r.P for r in trace.step_records],
            D = T[r.D for r in trace.step_records],
            B = T[r.B for r in trace.step_records],
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
