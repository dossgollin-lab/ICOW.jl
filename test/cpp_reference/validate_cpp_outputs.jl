# Validate Julia implementation against debugged C++ reference outputs

using Test

# Add parent directories to load path
push!(LOAD_PATH, joinpath(@__DIR__, "..", ".."))
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))

using ICOW

# Parse C++ output file
function parse_cpp_costs(filename)
    costs = Dict()
    current_case = nothing
    current_levers = nothing

    for line in eachline(filename)
        line = strip(line)
        if startswith(line, "# Test Case:")
            current_case = strip(split(line, ":")[2])
            costs[current_case] = Dict()
        elseif startswith(line, "# Levers:")
            # Parse: W=0, R=0, P=0, D=0, B=0
            levers_str = split(line, ":")[2]
            lever_pairs = split(levers_str, ",")
            levers = Dict()
            for pair in lever_pairs
                key, val = split(strip(pair), "=")
                levers[strip(key)] = parse(Float64, strip(val))
            end
            costs[current_case]["levers"] = levers
        elseif occursin(":", line) && !startswith(line, "#")
            key, val = split(line, ":")
            costs[current_case][strip(key)] = parse(Float64, strip(val))
        end
    end

    return costs
end

function parse_cpp_zones(filename)
    zones = Dict()
    current_case = nothing

    for line in eachline(filename)
        line = strip(line)
        if startswith(line, "# Test Case:")
            current_case = strip(split(line, ":")[2])
            zones[current_case] = Dict()
        elseif occursin(":", line) && !startswith(line, "#")
            key, val = split(line, ":")
            zones[current_case][strip(key)] = parse(Float64, strip(val))
        end
    end

    return zones
end

# Main validation
function main()
    println("=" ^ 60)
    println("Validating Julia implementation against C++ reference")
    println("=" ^ 60)

    # Parse C++ outputs
    costs_file = joinpath(@__DIR__, "outputs", "costs.txt")
    zones_file = joinpath(@__DIR__, "outputs", "zones.txt")

    cpp_costs = parse_cpp_costs(costs_file)
    cpp_zones = parse_cpp_zones(zones_file)

    # Setup Julia parameters (default city)
    city = CityParameters()

    # Test tolerance
    rtol = 1e-10

    # Test each case
    test_cases = sort(collect(keys(cpp_costs)))

    for test_name in test_cases
        println("\n--- Testing: $test_name ---")

        levers_dict = cpp_costs[test_name]["levers"]
        W = levers_dict["W"]
        R = levers_dict["R"]
        P = levers_dict["P"]
        D = levers_dict["D"]
        B = levers_dict["B"]

        levers = Levers(W, R, P, D, B)

        # Test withdrawal cost
        julia_wc = calculate_withdrawal_cost(city, W)
        cpp_wc = cpp_costs[test_name]["withdrawal_cost"]
        @test julia_wc ≈ cpp_wc rtol=rtol
        println("  ✓ Withdrawal cost: Julia=$julia_wc, C++=$cpp_wc")

        # Test resistance cost
        julia_rc = calculate_resistance_cost(city, levers)
        cpp_rc = cpp_costs[test_name]["resistance_cost"]
        @test julia_rc ≈ cpp_rc rtol=rtol
        println("  ✓ Resistance cost: Julia=$julia_rc, C++=$cpp_rc")

        # Test dike cost
        julia_dc = calculate_dike_cost(city, D, B)
        cpp_dc = cpp_costs[test_name]["dike_cost"]
        @test julia_dc ≈ cpp_dc rtol=rtol
        println("  ✓ Dike cost: Julia=$julia_dc, C++=$cpp_dc")

        # Test total investment cost
        julia_tic = calculate_investment_cost(city, levers)
        cpp_tic = cpp_costs[test_name]["total_investment_cost"]
        @test julia_tic ≈ cpp_tic rtol=rtol
        println("  ✓ Total investment: Julia=$julia_tic, C++=$cpp_tic")
    end

    println("\n" * "=" ^ 60)
    println("✓ All tests passed!")
    println("=" ^ 60)
end

# Run validation
main()
