# State types for stochastic and EAD simulation modes

"""
    StochasticState{T<:Real} <: AbstractSimulationState{T}

Mutable state for stochastic simulation mode.

Tracks the current protection levels, accumulated costs/damages,
and simulation progress. Updated in-place during simulation.

# Fields

- `current_levers::Levers{T}`: Current protection levels (enforces irreversibility)
- `accumulated_cost::T`: Total investment cost so far
- `accumulated_damage::T`: Total realized damages so far
- `current_year::Int`: Current simulation year (1-indexed)

# Examples

```julia
levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
state = StochasticState(levers)  # Initializes with zero costs at year 1
```
"""
mutable struct StochasticState{T<:Real} <: AbstractSimulationState{T}
    current_levers::Levers{T}
    accumulated_cost::T
    accumulated_damage::T
    current_year::Int
end

# Outer constructor: initialize accumulators to zero at year 1
StochasticState(levers::Levers{T}) where {T} = StochasticState(levers, zero(T), zero(T), 1)

"""
    EADState{T<:Real} <: AbstractSimulationState{T}

Mutable state for Expected Annual Damage (EAD) simulation mode.

Similar to StochasticState but tracks expected annual damage rather than
realized damages from specific surge events.

# Fields

- `current_levers::Levers{T}`: Current protection levels (enforces irreversibility)
- `accumulated_cost::T`: Total investment cost so far
- `accumulated_ead::T`: Total expected annual damage so far
- `current_year::Int`: Current simulation year (1-indexed)

# Examples

```julia
levers = Levers(0.0, 0.0, 0.0, 0.0, 0.0)
state = EADState(levers)  # Initializes with zero costs at year 1
```
"""
mutable struct EADState{T<:Real} <: AbstractSimulationState{T}
    current_levers::Levers{T}
    accumulated_cost::T
    accumulated_ead::T
    current_year::Int
end

# Outer constructor: initialize accumulators to zero at year 1
EADState(levers::Levers{T}) where {T} = EADState(levers, zero(T), zero(T), 1)
