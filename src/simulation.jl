# Simulation engine for the iCOW model
# Time-stepping loop with dual-mode support (stochastic and EAD)

using Random

# ============================================================================
# Main simulation functions (dispatch on forcing type)
# ============================================================================

"""
    simulate(city, policy, forcing::StochasticForcing; kwargs...)

Stochastic simulation mode. See docs/roadmap/phase07_simulation.md.
"""
function simulate(
    city::CityParameters{T},
    policy::AbstractPolicy{T},
    forcing::StochasticForcing{T};
    mode::Symbol=:scalar,
    scenario::Int=1,
    rng::AbstractRNG=Random.default_rng(),
    safe::Bool=false
) where {T<:Real}
    # Wrap in try-catch if safe mode requested
    if safe
        try
            return _simulate_stochastic(city, policy, forcing, mode, scenario, rng)
        catch e
            @warn "Simulation failed in safe mode" exception=e
            return (T(Inf), T(Inf))
        end
    else
        return _simulate_stochastic(city, policy, forcing, mode, scenario, rng)
    end
end

"""
    simulate(city, policy, forcing::DistributionalForcing; kwargs...)

Expected Annual Damage (EAD) simulation mode. See docs/roadmap/phase07_simulation.md.
"""
function simulate(
    city::CityParameters{T},
    policy::AbstractPolicy{T},
    forcing::DistributionalForcing{T,D};
    mode::Symbol=:scalar,
    method::Symbol=:mc,
    safe::Bool=false,
    kwargs...
) where {T<:Real, D<:Distribution}
    # Wrap in try-catch if safe mode requested
    if safe
        try
            return _simulate_ead(city, policy, forcing, mode, method; kwargs...)
        catch e
            @warn "Simulation failed in safe mode" exception=e
            return (T(Inf), T(Inf))
        end
    else
        return _simulate_ead(city, policy, forcing, mode, method; kwargs...)
    end
end

# ============================================================================
# Internal simulation implementations
# ============================================================================

function _simulate_stochastic(
    city::CityParameters{T},
    policy::AbstractPolicy{T},
    forcing::StochasticForcing{T},
    mode::Symbol,
    scenario::Int,
    rng::AbstractRNG
) where {T<:Real}
    # Initialize state with zero levers (first year pays full cost)
    state = StochasticState(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)))

    n = n_years(forcing)

    # Preallocate trace arrays if needed
    if mode == :trace
        year_vec = Vector{Int}(undef, n)
        W_vec = Vector{T}(undef, n)
        R_vec = Vector{T}(undef, n)
        P_vec = Vector{T}(undef, n)
        D_vec = Vector{T}(undef, n)
        B_vec = Vector{T}(undef, n)
        investment_vec = Vector{T}(undef, n)
        damage_vec = Vector{T}(undef, n)
    end

    # Main time-stepping loop
    for year in 1:n
        # Get policy decision (target levers)
        target = policy(state, forcing, year)

        # Enforce irreversibility: can only increase protection
        new_levers = max(state.current_levers, target)

        # Validate feasibility (after irreversibility enforcement)
        @assert is_feasible(new_levers, city) "Infeasible levers after irreversibility enforcement"

        # Calculate marginal investment cost (only pay for NEW infrastructure)
        cost = _marginal_cost(city, state.current_levers, new_levers)

        # Get surge for this scenario and year
        h_raw = get_surge(forcing, scenario, year)

        # Apply seawall and runup effects
        h_eff = calculate_effective_surge(h_raw, city)

        # Calculate damage (stochastic: samples dike failure)
        damage = calculate_event_damage_stochastic(h_eff, city, new_levers, rng)

        # Update state
        _update_state!(state, new_levers, cost, damage)

        # Record trace if needed
        if mode == :trace
            year_vec[year] = year
            W_vec[year] = new_levers.W
            R_vec[year] = new_levers.R
            P_vec[year] = new_levers.P
            D_vec[year] = new_levers.D
            B_vec[year] = new_levers.B
            investment_vec[year] = cost
            damage_vec[year] = damage
        end
    end

    # Return based on mode
    if mode == :scalar
        return (state.accumulated_cost, state.accumulated_damage)
    else
        return _finalize_trace(year_vec, W_vec, R_vec, P_vec, D_vec, B_vec, investment_vec, damage_vec)
    end
end

function _simulate_ead(
    city::CityParameters{T},
    policy::AbstractPolicy{T},
    forcing::DistributionalForcing{T,D},
    mode::Symbol,
    method::Symbol;
    kwargs...
) where {T<:Real, D<:Distribution}
    # Initialize state with zero levers (first year pays full cost)
    state = EADState(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)))

    n = n_years(forcing)

    # Preallocate trace arrays if needed
    if mode == :trace
        year_vec = Vector{Int}(undef, n)
        W_vec = Vector{T}(undef, n)
        R_vec = Vector{T}(undef, n)
        P_vec = Vector{T}(undef, n)
        D_vec = Vector{T}(undef, n)
        B_vec = Vector{T}(undef, n)
        investment_vec = Vector{T}(undef, n)
        ead_vec = Vector{T}(undef, n)
    end

    # Main time-stepping loop
    for year in 1:n
        # Get policy decision (target levers)
        target = policy(state, forcing, year)

        # Enforce irreversibility: can only increase protection
        new_levers = max(state.current_levers, target)

        # Validate feasibility (after irreversibility enforcement)
        @assert is_feasible(new_levers, city) "Infeasible levers after irreversibility enforcement"

        # Calculate marginal investment cost (only pay for NEW infrastructure)
        cost = _marginal_cost(city, state.current_levers, new_levers)

        # Calculate expected annual damage (integrates over surge distribution)
        ead = calculate_expected_damage(city, new_levers, forcing, year; method, kwargs...)

        # Update state
        _update_state!(state, new_levers, cost, ead)

        # Record trace if needed
        if mode == :trace
            year_vec[year] = year
            W_vec[year] = new_levers.W
            R_vec[year] = new_levers.R
            P_vec[year] = new_levers.P
            D_vec[year] = new_levers.D
            B_vec[year] = new_levers.B
            investment_vec[year] = cost
            ead_vec[year] = ead
        end
    end

    # Return based on mode
    if mode == :scalar
        return (state.accumulated_cost, state.accumulated_ead)
    else
        return _finalize_trace(year_vec, W_vec, R_vec, P_vec, D_vec, B_vec, investment_vec, ead_vec)
    end
end

# ============================================================================
# Internal helper functions
# ============================================================================

"""
    _marginal_cost(city, old_levers, new_levers)

Calculate marginal investment cost (only charge for NEW infrastructure).
Returns max(0, cost_new - cost_old). Handles first year automatically.
"""
function _marginal_cost(city::CityParameters{T}, old_levers::Levers{T}, new_levers::Levers{T}) where {T<:Real}
    cost_old = calculate_investment_cost(city, old_levers)
    cost_new = calculate_investment_cost(city, new_levers)
    return max(zero(T), cost_new - cost_old)
end

"""
    _update_state!(state::StochasticState, levers, cost, damage)

Update stochastic state in-place. Accumulates costs and damages.
"""
function _update_state!(state::StochasticState{T}, levers::Levers{T}, cost::T, damage::T) where {T<:Real}
    state.current_levers = levers
    state.accumulated_cost += cost
    state.accumulated_damage += damage
    state.current_year += 1
    return nothing
end

"""
    _update_state!(state::EADState, levers, cost, ead)

Update EAD state in-place. Accumulates costs and expected annual damages.
"""
function _update_state!(state::EADState{T}, levers::Levers{T}, cost::T, ead::T) where {T<:Real}
    state.current_levers = levers
    state.accumulated_cost += cost
    state.accumulated_ead += ead
    state.current_year += 1
    return nothing
end

"""
    _finalize_trace(year_vec, W_vec, R_vec, P_vec, D_vec, B_vec, investment_vec, damage_vec)

Construct NamedTuple trace from preallocated vectors.
"""
function _finalize_trace(
    year_vec::Vector{Int},
    W_vec::Vector{T},
    R_vec::Vector{T},
    P_vec::Vector{T},
    D_vec::Vector{T},
    B_vec::Vector{T},
    investment_vec::Vector{T},
    damage_vec::Vector{T}
) where {T<:Real}
    return (
        year = year_vec,
        W = W_vec,
        R = R_vec,
        P = P_vec,
        D = D_vec,
        B = B_vec,
        investment = investment_vec,
        damage = damage_vec
    )
end
