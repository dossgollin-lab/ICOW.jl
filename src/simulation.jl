# Simulation engine for the iCOW model
# Time-stepping loop with dual-mode support (stochastic and EAD)

using Random

# ============================================================================
# Main simulation functions (dispatch on forcing type)
# ============================================================================

"""
    simulate(city, policy, forcing::StochasticForcing; kwargs...)

Stochastic simulation mode. See docs/equations.md.
"""
function simulate(
    city::CityParameters{T},
    policy::AbstractPolicy{T},
    forcing::StochasticForcing{T};
    mode::Symbol=:scalar,
    scenario::Int=1,
    rng::AbstractRNG=Random.default_rng(),
    discount_rate::Real=0.0
) where {T<:Real}
    # Create damage function for stochastic mode
    damage_fn = (year, levers) -> begin
        h_raw = get_surge(forcing, scenario, year)
        calculate_event_damage_stochastic(h_raw, city, levers, rng)
    end

    state = State(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)))
    return _simulate_core(city, policy, forcing, state, mode, T(discount_rate), damage_fn)
end

"""
    simulate(city, policy, forcing::DistributionalForcing; kwargs...)

Expected Annual Damage (EAD) simulation mode. See docs/equations.md.
"""
function simulate(
    city::CityParameters{T},
    policy::AbstractPolicy{T},
    forcing::DistributionalForcing{T,D};
    mode::Symbol=:scalar,
    method::Symbol=:quad,
    discount_rate::Real=0.0,
    kwargs...
) where {T<:Real, D<:Distribution}
    # Create damage function for EAD mode
    damage_fn = (year, levers) -> calculate_expected_damage(city, levers, forcing, year; method, kwargs...)

    state = State(Levers{T}(zero(T), zero(T), zero(T), zero(T), zero(T)))
    return _simulate_core(city, policy, forcing, state, mode, T(discount_rate), damage_fn)
end

# ============================================================================
# Core simulation loop (shared by both modes)
# ============================================================================

"""
    _simulate_core(city, policy, forcing, state, mode, discount_rate, damage_fn)

Internal: unified time-stepping loop for both stochastic and EAD modes.
damage_fn: (year, levers) -> damage value
"""
function _simulate_core(
    city::CityParameters{T},
    policy::AbstractPolicy{T},
    forcing::AbstractForcing{T},
    state::AbstractSimulationState{T},
    mode::Symbol,
    discount_rate::T,
    damage_fn
) where {T<:Real}
    n = n_years(forcing)

    # Accumulators (NOT part of state - these are outputs)
    accumulated_cost = zero(T)
    accumulated_damage = zero(T)

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

        # Calculate damage using the provided function
        damage = damage_fn(year, new_levers)

        # Apply discounting (year is 1-indexed, so year 1 has factor 1/(1+r)^1)
        discount_factor = one(T) / (one(T) + discount_rate)^year
        accumulated_cost += cost * discount_factor
        accumulated_damage += damage * discount_factor

        # Update state (only physical state, not accumulators)
        state.current_levers = new_levers
        state.current_year = year + 1

        # Record trace if needed (store undiscounted values for analysis)
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
        return (accumulated_cost, accumulated_damage)
    else
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
