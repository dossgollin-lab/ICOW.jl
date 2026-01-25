# Stochastic simulation types for SimOptDecisions integration

# =============================================================================
# StochasticConfig - flattened city parameters
# =============================================================================

"""
    StochasticConfig{T<:Real}

Configuration for stochastic flood simulation with all city parameters.
See _background/equations.md for parameter documentation.
"""
Base.@kwdef struct StochasticConfig{T<:Real} <: SimOptDecisions.AbstractConfig
    # Geometry (6)
    V_city::T = 1.5e12      # Initial city value (\$)
    H_bldg::T = 30.0        # Building height (m)
    H_city::T = 17.0        # City max elevation (m)
    D_city::T = 2000.0      # City depth from seawall to peak (m)
    W_city::T = 43000.0     # City coastline length (m)
    H_seawall::T = 1.75     # Seawall height (m)

    # Dike (4)
    D_startup::T = 2.0      # Startup height for fixed costs (m)
    w_d::T = 3.0            # Dike top width (m)
    s_dike::T = 0.5         # Dike side slope (horizontal/vertical)
    c_d::T = 10.0           # Dike cost per volume (\$/m^3)

    # Zones (2)
    r_prot::T = 1.1         # Protected zone value ratio
    r_unprot::T = 0.95      # Unprotected zone value ratio

    # Withdrawal (2)
    f_w::T = 1.0            # Withdrawal cost factor
    f_l::T = 0.01           # Loss fraction (leaves vs relocates)

    # Resistance (5)
    f_adj::T = 1.25         # Adjustment factor
    f_lin::T = 0.35         # Linear cost factor
    f_exp::T = 0.115        # Exponential cost factor
    t_exp::T = 0.4          # Exponential threshold
    b_basement::T = 3.0     # Basement depth (m)

    # Damage (6)
    f_damage::T = 0.39      # Fraction of value lost per flood
    f_intact::T = 0.03      # Damage factor when dike holds
    f_failed::T = 1.5       # Damage factor when dike fails
    t_fail::T = 0.95        # Surge/height ratio for failure onset
    p_min::T = 0.05         # Minimum dike failure probability
    f_runup::T = 1.1        # Wave runup amplification factor

    # Threshold (3)
    d_thresh::T = 4.0e9     # Damage threshold (\$)
    f_thresh::T = 1.0       # Threshold fraction multiplier
    gamma_thresh::T = 1.01  # Threshold exponent
end

"""
    validate_config(config::StochasticConfig)

Validate physical bounds on config parameters. Throws AssertionError if violated.
"""
function validate_config(config::StochasticConfig)
    # Positive values (must be > 0)
    @assert config.V_city > 0 "V_city must be positive"
    @assert config.H_bldg > 0 "H_bldg must be positive"
    @assert config.H_city > 0 "H_city must be positive"
    @assert config.D_city > 0 "D_city must be positive"
    @assert config.W_city > 0 "W_city must be positive"
    @assert config.s_dike > 0 "s_dike must be positive"

    # Non-negative values (>= 0)
    @assert config.H_seawall >= 0 "H_seawall must be non-negative"
    @assert config.D_startup >= 0 "D_startup must be non-negative"
    @assert config.w_d >= 0 "w_d must be non-negative"
    @assert config.c_d >= 0 "c_d must be non-negative"
    @assert config.b_basement >= 0 "b_basement must be non-negative"
    @assert config.d_thresh >= 0 "d_thresh must be non-negative"

    # Fractions in [0, 1]
    @assert 0 <= config.f_l <= 1 "f_l must be in [0, 1]"
    @assert 0 <= config.f_damage <= 1 "f_damage must be in [0, 1]"
    @assert 0 <= config.t_fail <= 1 "t_fail must be in [0, 1]"
    @assert 0 <= config.p_min <= 1 "p_min must be in [0, 1]"
    @assert 0 <= config.t_exp <= 1 "t_exp must be in [0, 1]"

    # Positive multipliers
    @assert config.f_w > 0 "f_w must be positive"
    @assert config.f_adj > 0 "f_adj must be positive"
    @assert config.r_prot > 0 "r_prot must be positive"
    @assert config.r_unprot > 0 "r_unprot must be positive"

    # f_runup should amplify, not attenuate
    @assert config.f_runup >= 1.0 "f_runup must be >= 1.0"

    return nothing
end

# Hook into SimOptDecisions validation
SimOptDecisions.validate_config(config::StochasticConfig) = validate_config(config)

"""
    is_feasible(fd::FloodDefenses, config::StochasticConfig) -> Bool

Check if flood defenses are feasible for the given config.
"""
function is_feasible(fd::FloodDefenses, config::StochasticConfig)
    # W < H_city (strict); W = H_city causes division by zero in withdrawal_cost
    fd.W < config.H_city || return false

    # W + B + D <= H_city; dike top cannot exceed city elevation
    fd.W + fd.B + fd.D <= config.H_city || return false

    return true
end

# =============================================================================
# StochasticScenario - surge time series
# =============================================================================

SimOptDecisions.@scenariodef StochasticScenario begin
    @timeseries surges
    @continuous discount_rate 0.0 1.0
end

# =============================================================================
# StochasticState - current protection levels
# =============================================================================

"""
    StochasticState{T<:AbstractFloat}

Simulation state tracking current flood defenses.
"""
mutable struct StochasticState{T<:AbstractFloat} <: SimOptDecisions.AbstractState
    defenses::FloodDefenses{T}
end

StochasticState{T}() where {T<:AbstractFloat} = StochasticState(
    FloodDefenses{T}(zero(T), zero(T), zero(T), zero(T), zero(T))
)

# =============================================================================
# StaticPolicy - reparameterized for optimization
# =============================================================================

SimOptDecisions.@policydef StaticPolicy begin
    @continuous a_frac 0.0 1.0  # total height budget as fraction of H_city
    @continuous w_frac 0.0 1.0  # W's share of budget
    @continuous b_frac 0.0 1.0  # B's share of remaining (A - W)
    @continuous r_frac 0.0 1.0  # R as fraction of H_city
    @continuous P 0.0 0.99      # resistance fraction
end

"""
    FloodDefenses(policy::StaticPolicy, config::StochasticConfig)

Convert reparameterized policy fractions to absolute FloodDefenses values.
Uses stick-breaking reparameterization to ensure constraints are always satisfied.
"""
function FloodDefenses(policy::StaticPolicy, config::StochasticConfig)
    H = config.H_city
    A = SimOptDecisions.value(policy.a_frac) * H
    W = SimOptDecisions.value(policy.w_frac) * A
    remaining = A - W
    B = SimOptDecisions.value(policy.b_frac) * remaining
    D = remaining - B
    R = SimOptDecisions.value(policy.r_frac) * H
    P = SimOptDecisions.value(policy.P)
    return FloodDefenses(W, R, P, D, B)
end

# =============================================================================
# StochasticOutcome - simulation results
# =============================================================================

SimOptDecisions.@outcomedef StochasticOutcome begin
    @continuous investment
    @continuous damage
end

"""Total cost is investment plus damage."""
total_cost(o::StochasticOutcome) = SimOptDecisions.value(o.investment) + SimOptDecisions.value(o.damage)
