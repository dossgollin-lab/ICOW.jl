# Discounting and objective functions for the iCOW model
# Separated from simulation to allow flexible re-analysis

"""
    apply_discount(value, year, discount_rate)

Apply discount factor to a value. Returns value / (1 + discount_rate)^year.
"""
function apply_discount(value::Real, year::Int, discount_rate::Real)
    return value / (one(discount_rate) + discount_rate)^year
end

"""
    calculate_npv(trace::NamedTuple, discount_rate)

Calculate Net Present Value from simulation trace.
Returns (npv_investment, npv_damage) tuple with discounted totals.
"""
function calculate_npv(trace::NamedTuple, discount_rate::Real)
    @assert haskey(trace, :year) "Trace must have :year field"
    @assert haskey(trace, :investment) "Trace must have :investment field"
    @assert haskey(trace, :damage) "Trace must have :damage field"

    # Apply discount factors to each year
    npv_investment = sum(apply_discount(trace.investment[i], trace.year[i], discount_rate)
                         for i in eachindex(trace.year))
    npv_damage = sum(apply_discount(trace.damage[i], trace.year[i], discount_rate)
                     for i in eachindex(trace.year))

    return (npv_investment, npv_damage)
end

"""
    objective_total_cost(city, policy, forcing, discount_rate; kwargs...)

Objective function for optimization: total discounted cost (investment + damage).
"""
function objective_total_cost(
    city::CityParameters,
    policy::AbstractPolicy,
    forcing::AbstractForcing,
    discount_rate::Real;
    kwargs...
)
    # Run simulation in trace mode to get year-by-year flows
    trace = simulate(city, policy, forcing; mode=:trace, kwargs...)

    # Calculate NPV
    (npv_investment, npv_damage) = calculate_npv(trace, discount_rate)

    # Return total discounted cost
    return npv_investment + npv_damage
end
