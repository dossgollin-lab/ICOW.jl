"""
    CityParameters

Immutable struct holding all exogenous parameters for the iCOW model.

Parameters are based on Table C.3 from Ceres et al. (2019), p. 33.
All parameters have physical units and default values matching the paper.

See docs/parameters.md for detailed parameter descriptions.
"""
Base.@kwdef struct CityParameters
    # City geometry
    total_value::Float64 = 1.5e12      # vi: Initial city value ($)
    building_height::Float64 = 30.0     # B: Building height (m)
    city_max_height::Float64 = 17.0     # Hcity: Height of city (m)
    city_depth::Float64 = 2000.0        # Depth from seawall to highest point (m)
    city_length::Float64 = 43000.0      # Length of seawall coast (m)
    seawall_height::Float64 = 1.75      # Height of seawall (m)
    city_slope::Float64 = 17.0/2000.0   # S: Slope of the wedge

    # Dike parameters
    dike_startup_height::Float64 = 3.0  # Equivalent height for startup costs (m)
    dike_top_width::Float64 = 4.0       # Width of dike top (m)
    dike_side_slope::Float64 = 0.5      # s: Slope of dike sides (m/m)
    dike_cost_per_m3::Float64 = 10.0    # cdpv: Cost per cubic meter ($)
    dike_value_ratio::Float64 = 1.1     # Value increase in dike-protected areas

    # Withdrawal parameters
    withdrawal_factor::Float64 = 1.0    # fw: Cost adjustment factor
    withdrawal_fraction::Float64 = 0.01 # fl: Fraction that leaves vs relocates

    # Resistance parameters
    resistance_linear_factor::Float64 = 0.35    # flin: Linear cost factor
    resistance_exp_factor::Float64 = 0.9        # fexp: Exponential cost factor
    resistance_threshold::Float64 = 0.6         # texp: Threshold for exponential costs
    basement_depth::Float64 = 3.0               # Representative basement depth (m)

    # Damage parameters
    damage_fraction::Float64 = 0.39             # fdamage: Fraction of inundated buildings damaged
    protected_damage_factor::Float64 = 1.3      # Increased damage when dike fails
    dike_failure_threshold::Float64 = 0.95      # tdf: Threshold for failure probability
    threshold_damage_level::Float64 = 1/375     # Damage threshold as fraction of city value
    wave_runup_factor::Float64 = 1.1            # Surge increase factor when overtopping

    # Economic parameters
    discount_rate::Float64 = 0.04       # Annual discount rate

    # Simulation parameters
    n_years::Int = 50                   # Simulation time horizon
end

"""
    validate_parameters(city::CityParameters) -> Bool

Validate CityParameters for physical consistency.

Throws ArgumentError if invalid.

# Checks
- All values are positive where required
- City height exceeds seawall height
- Discount rate is in valid range (0, 1)
- City slope matches geometry
- Resistance threshold is in [0, 1]
- Number of simulation years is positive
"""
function validate_parameters(city::CityParameters)
    @assert city.total_value > 0 "City value must be positive"
    @assert city.city_max_height > city.seawall_height "City must be higher than seawall"
    @assert 0 < city.discount_rate < 1 "Discount rate must be in (0, 1)"
    @assert city.city_slope ≈ city.city_max_height / city.city_depth "Inconsistent slope"
    @assert 0 ≤ city.resistance_threshold ≤ 1 "Resistance threshold must be in [0, 1]"
    @assert city.n_years > 0 "Simulation years must be positive"
    return true
end
