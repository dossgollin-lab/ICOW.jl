# Stochastic simulation submodule for ICOW
# Implements discrete event simulation via SimOptDecisions

module Stochastic

import ..ICOW: FloodDefenses, StaticPolicy, validate_config, is_feasible, total_cost
using ..ICOW: Core
using SimOptDecisions
using Random

include("types.jl")
include("simulation.jl")

export FloodDefenses
export StochasticConfig, StochasticScenario, StochasticState
export StaticPolicy, StochasticOutcome
export validate_config, is_feasible, total_cost

# Re-export SimOptDecisions utilities for convenience
using SimOptDecisions: simulate, value, explore, outcomes_for_policy, outcomes_for_scenario
export simulate, value, explore, outcomes_for_policy, outcomes_for_scenario

end # module Stochastic
