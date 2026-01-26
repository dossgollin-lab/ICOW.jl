@testset "Aqua.jl" begin
    using Aqua
    Aqua.test_all(ICOW; deps_compat=(; ignore=[:Random]))
end
