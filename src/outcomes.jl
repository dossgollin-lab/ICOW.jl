# Outcome type for ICOW simulations
# Outcomes are the result of a single simulation run

"""
    ICOWOutcome{T} <: SimOptDecisions.AbstractOutcome

Result of an ICOW simulation: total discounted investment and damage.
"""
struct ICOWOutcome{T<:AbstractFloat} <: SimOptDecisions.AbstractOutcome
    investment::T
    damage::T
end

# Total cost accessor
total_cost(o::ICOWOutcome) = o.investment + o.damage

# Display
function Base.show(io::IO, o::ICOWOutcome)
    print(io, "ICOWOutcome(inv=\$$(round(o.investment/1e9, digits=2))B, dmg=\$$(round(o.damage/1e9, digits=2))B)")
end
