# Validate Core physics functions against debugged C++ reference outputs
#
# The C++ reference (icow_debugged.cpp) has all 7 bugs fixed to match paper formulas.
# Output files in outputs/ are committed and used for regression testing.
# See outputs/summary.txt for provenance and bug fix details.
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

# Parse C++ output file (works for costs.txt and zones.txt)
function parse_cpp_output(filename)
    data = Dict{String,Dict{String,Any}}()
    current_case = nothing

    for line in eachline(filename)
        line = strip(line)
        if startswith(line, "# Test Case:")
            current_case = strip(split(line, ":")[2])
            data[current_case] = Dict{String,Any}()
        elseif startswith(line, "# Levers:")
            levers_str = split(line, ":")[2]
            lever_pairs = split(levers_str, ",")
            levers = Dict{String,Float64}()
            for pair in lever_pairs
                key, val = split(strip(pair), "=")
                levers[strip(key)] = parse(Float64, strip(val))
            end
            data[current_case]["levers"] = levers
        elseif occursin(":", line) && !startswith(line, "#")
            key, val = split(line, ":")
            data[current_case][strip(key)] = parse(Float64, strip(val))
        end
    end

    return data
end

@testset "C++ Reference Validation" begin
    # Parse committed C++ outputs
    output_dir = joinpath(@__DIR__, "..", "validation", "cpp_reference", "outputs")
    costs_file = joinpath(output_dir, "costs.txt")
    zones_file = joinpath(output_dir, "zones.txt")
    @test isfile(costs_file)
    @test isfile(zones_file)

    cpp_costs = parse_cpp_output(costs_file)
    cpp_zones = parse_cpp_output(zones_file)

    # Validation tolerance (floating-point precision)
    rtol = 1e-10

    test_cases = sort(collect(keys(cpp_costs)))
    @test length(test_cases) == 8  # 8 test cases in C++ reference

    @testset "Cost functions" begin
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
                @test julia_wc ≈ cpp_costs[test_name]["withdrawal_cost"] rtol = rtol

                # Test value after withdrawal
                julia_vw = ICOWCore.value_after_withdrawal(CPP_V_CITY, CPP_H_CITY, CPP_F_L, W)
                @test julia_vw ≈ cpp_costs[test_name]["value_after_withdrawal"] rtol = rtol

                # Test resistance cost
                f_cR = ICOWCore.resistance_cost_fraction(CPP_F_ADJ, CPP_F_LIN, CPP_F_EXP, CPP_T_EXP, P)
                julia_rc = ICOWCore.resistance_cost(julia_vw, f_cR, CPP_H_BLDG, CPP_H_CITY, W, R, B, CPP_B_BASEMENT)
                @test julia_rc ≈ cpp_costs[test_name]["resistance_cost"] rtol = rtol
            end
        end
    end

    @testset "Zone boundaries and values" begin
        for test_name in test_cases
            @testset "$test_name" begin
                levers = cpp_zones[test_name]["levers"]
                W = levers["W"]
                R = levers["R"]
                D = levers["D"]
                B = levers["B"]

                # Zone boundaries: C++ outputs zone1_top..zone4_top = z1_high..z4_high
                bounds = ICOWCore.zone_boundaries(CPP_H_CITY, W, R, B, D)
                @test bounds[4] ≈ cpp_zones[test_name]["zone1_top"] rtol = rtol   # z1_high
                @test bounds[6] ≈ cpp_zones[test_name]["zone2_top"] rtol = rtol   # z2_high
                @test bounds[8] ≈ cpp_zones[test_name]["zone3_top"] rtol = rtol   # z3_high
                @test bounds[10] ≈ cpp_zones[test_name]["zone4_top"] rtol = rtol  # z4_high

                # Zone values: C++ outputs zone1_value..zone4_value = val_z1..val_z4
                V_w = ICOWCore.value_after_withdrawal(CPP_V_CITY, CPP_H_CITY, CPP_F_L, W)
                values = ICOWCore.zone_values(V_w, CPP_H_CITY, W, R, B, D, CPP_R_PROT, CPP_R_UNPROT)
                @test values[2] ≈ cpp_zones[test_name]["zone1_value"] rtol = rtol  # val_z1
                @test values[3] ≈ cpp_zones[test_name]["zone2_value"] rtol = rtol  # val_z2
                @test values[4] ≈ cpp_zones[test_name]["zone3_value"] rtol = rtol  # val_z3
                @test values[5] ≈ cpp_zones[test_name]["zone4_value"] rtol = rtol  # val_z4
            end
        end
    end
end
