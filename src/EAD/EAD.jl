# EAD (Expected Annual Damage) submodule for ICOW
# Implements integration over surge distributions via SimOptDecisions

module EAD

import ..ICOW: FloodDefenses
using ..ICOW: Core
using SimOptDecisions
using Random
using Distributions
using QuadGK

include("types.jl")
include("simulation.jl")

export IntegrationMethod, QuadratureIntegrator, MonteCarloIntegrator
export EADConfig, EADScenario, EADState
export StaticPolicy, EADOutcome
export validate_config, is_feasible, total_cost

# Re-export simulate for convenience
using SimOptDecisions: simulate
export simulate

end # module EAD
