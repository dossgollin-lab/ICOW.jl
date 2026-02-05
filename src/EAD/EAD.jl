# EAD (Expected Annual Damage) submodule for ICOW
# Implements integration over surge distributions via SimOptDecisions

module EAD

import ..ICOW: FloodDefenses, StaticPolicy, validate_config, is_feasible, total_cost, _show_config_params
using ..ICOW: Core
using SimOptDecisions
using Random
using Distributions
using QuadGK

include("types.jl")
include("simulation.jl")

export FloodDefenses
export IntegrationMethod, QuadratureIntegrator, MonteCarloIntegrator
export EADConfig, EADScenario, EADState
export StaticPolicy, EADOutcome
export validate_config, is_feasible, total_cost

# Re-export SimOptDecisions utilities for convenience
using SimOptDecisions: simulate, value, explore, outcomes_for_policy, outcomes_for_scenario
export simulate, value, explore, outcomes_for_policy, outcomes_for_scenario

end # module EAD
