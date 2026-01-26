@testset "Aqua.jl" begin
    using Aqua
    # persistent_tasks=false: Aqua can't resolve unregistered dep SimOptDecisions in a fresh env
    Aqua.test_all(ICOW; persistent_tasks=false, deps_compat=(; ignore=[:Random]))
end
