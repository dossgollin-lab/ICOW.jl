module ICOW

using SimOptDecisions

# Types (plain structs, no dependencies)
include("types.jl")
export FloodDefenses

# Shared policy type (identical for both Stochastic and EAD modes)
SimOptDecisions.@policydef StaticPolicy begin
    @continuous a_frac 0.0 1.0  # total height budget as fraction of H_city
    @continuous w_frac 0.0 1.0  # W's share of budget
    @continuous b_frac 0.0 1.0  # B's share of remaining (A - W)
    @continuous r_frac 0.0 1.0  # R as fraction of H_city
    @continuous P 0.0 0.99      # resistance fraction
end
export StaticPolicy

function Base.show(io::IO, p::StaticPolicy)
    print(
        io,
        "StaticPolicy(",
        "a_frac=",
        SimOptDecisions.value(p.a_frac),
        ", w_frac=",
        SimOptDecisions.value(p.w_frac),
        ", b_frac=",
        SimOptDecisions.value(p.b_frac),
        ", r_frac=",
        SimOptDecisions.value(p.r_frac),
        ", P=",
        SimOptDecisions.value(p.P),
        ")",
    )
end

# Shared functions dispatched on config/outcome type in submodules
function validate_config end
function is_feasible end
function total_cost end
export validate_config, is_feasible, total_cost

# Core submodule (pure physics functions)
include("Core/Core.jl")
using .Core

# Stochastic submodule (SimOptDecisions integration)
include("Stochastic/Stochastic.jl")
using .Stochastic
export Stochastic

# EAD submodule (Expected Annual Damage integration)
include("EAD/EAD.jl")
using .EAD
export EAD

end # module ICOW
