# Stochastic simulation submodule for ICOW
# Implements discrete event simulation via SimOptDecisions

module Stochastic

import ..ICOW: FloodDefenses
using ..ICOW: Core
using SimOptDecisions
using Random

include("types.jl")
include("simulation.jl")

export StochasticConfig, StochasticScenario, StochasticState
export StaticPolicy, StochasticOutcome
export validate_config, is_feasible, total_cost

end # module Stochastic
