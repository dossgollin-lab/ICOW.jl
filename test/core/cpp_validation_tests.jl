# Validate Core physics functions against debugged C++ reference outputs
#
# The C++ reference (icow_debugged.cpp) has all 7 bugs fixed to match paper formulas.
# Output files in outputs/ are committed and used for regression testing.
#
# NOTE: Dike cost is NOT validated because Julia uses a corrected geometric formula
# for dike volume. See _background/equations.md Equation 6 for details.

const ICOWCore = ICOW.Core

# Default city parameters (must match C++ defaults)
const CPP_V_CITY = 1.5e12
const CPP_H_BLDG = 30.0
const CPP_H_CITY = 17.0
const CPP_D_CITY = 2000.0
const CPP_W_CITY = 43000.0
const CPP_H_SEAWALL = 1.75

const CPP_D_STARTUP = 2.0
const CPP_W_D = 3.0
const CPP_S_DIKE = 0.5
const CPP_C_D = 10.0

const CPP_R_PROT = 1.1
const CPP_R_UNPROT = 0.95

const CPP_F_W = 1.0
const CPP_F_L = 0.01

const CPP_F_ADJ = 1.25
const CPP_F_LIN = 0.35
const CPP_F_EXP = 0.115
const CPP_T_EXP = 0.4
const CPP_B_BASEMENT = 3.0

const CPP_F_DAMAGE = 0.39
const CPP_F_INTACT = 0.03
const CPP_F_FAILED = 1.5
const CPP_T_FAIL = 0.95
const CPP_P_MIN = 0.05
const CPP_F_RUNUP = 1.1

# Parse C++ output file
function parse_cpp_costs(filename)
    costs = Dict{String,Dict{String,Any}}()
    current_case = nothing

    for line in eachline(filename)
        line = strip(line)
        if startswith(line, "# Test Case:")
            current_case = strip(split(line, ":")[2])
            costs[current_case] = Dict{String,Any}()
        elseif startswith(line, "# Levers:")
            levers_str = split(line, ":")[2]
            lever_pairs = split(levers_str, ",")
            levers = Dict{String,Float64}()
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

@testset "C++ Reference Validation" begin
    # Parse committed C++ outputs
    costs_file = joinpath(@__DIR__, "..", "validation", "cpp_reference", "outputs", "costs.txt")
    @test isfile(costs_file)

    cpp_costs = parse_cpp_costs(costs_file)

    # Validation tolerance (floating-point precision)
    rtol = 1e-10

    # Test each case
    test_cases = sort(collect(keys(cpp_costs)))
    @test length(test_cases) == 8  # 8 test cases in C++ reference

    for test_name in test_cases
        @testset "$test_name" begin
            levers = cpp_costs[test_name]["levers"]
            W = levers["W"]
            R = levers["R"]
            P = levers["P"]
            D = levers["D"]
            B = levers["B"]

            # Test withdrawal cost
            julia_wc = ICOWCore.withdrawal_cost(CPP_V_CITY, CPP_H_CITY, CPP_F_W, W)
            cpp_wc = cpp_costs[test_name]["withdrawal_cost"]
            @test julia_wc ≈ cpp_wc rtol=rtol

            # Test value after withdrawal
            julia_vw = ICOWCore.value_after_withdrawal(CPP_V_CITY, CPP_H_CITY, CPP_F_L, W)
            cpp_vw = cpp_costs[test_name]["value_after_withdrawal"]
            @test julia_vw ≈ cpp_vw rtol=rtol

            # Test resistance cost
            f_cR = ICOWCore.resistance_cost_fraction(CPP_F_ADJ, CPP_F_LIN, CPP_F_EXP, CPP_T_EXP, P)
            julia_rc = ICOWCore.resistance_cost(julia_vw, f_cR, CPP_H_BLDG, CPP_H_CITY, W, R, B, CPP_B_BASEMENT)
            cpp_rc = cpp_costs[test_name]["resistance_cost"]
            @test julia_rc ≈ cpp_rc rtol=rtol
        end
    end
end
