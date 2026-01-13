using ICOW

# edge_r_geq_b case: W=0, R=6, P=0.5, D=3, B=5
city = CityParameters()
levers = Levers(0.0, 6.0, 0.5, 3.0, 5.0)

println("=== edge_r_geq_b Debug ===")
println("Levers: W=$(levers.W), R=$(levers.R), P=$(levers.P), D=$(levers.D), B=$(levers.B)")
println()

# Calculate components
V_w = calculate_value_after_withdrawal(city, levers.W)
f_cR = calculate_resistance_cost_fraction(city, levers.P)

println("V_w = ", V_w)
println("f_cR = ", f_cR)
println()

# Julia formula (Equation 5): R >= B case
denominator = city.H_bldg * (city.H_city - levers.W)
numerator = V_w * f_cR * levers.B * (levers.R - levers.B / 2 + city.b_basement)

println("Julia formula (Equation 5):")
println("  numerator = V_w * f_cR * B * (R - B/2 + b)")
println("           = $V_w * $f_cR * $(levers.B) * ($(levers.R) - $(levers.B/2) + $(city.b_basement))")
println("           = $numerator")
println("  denominator = H_bldg * (H_city - W)")
println("             = $(city.H_bldg) * ($(city.H_city) - $(levers.W))")
println("             = $denominator")
println("  C_R = $numerator / $denominator")
println("      = $(numerator / denominator)")
println()

# What C++ does (from CalculateResiliencyCost2):
# vz1 = tcvaw * DikeUnprotectedValuationRatio * dbh / (CEC - wh)
r_unprot = 0.95  # DikeUnprotectedValuationRatio from C++
vz1 = V_w * r_unprot * levers.B / (city.H_city - levers.W)
cpp_numerator = vz1 * f_cR * (city.b_basement + levers.R - levers.B/2)

println("C++ formula:")
println("  vz1 = V_w * r_unprot * B / (H_city - W)")
println("      = $V_w * $r_unprot * $(levers.B) / $(city.H_city - levers.W)")
println("      = $vz1")
println("  C_R = vz1 * f_cR * (b + R - B/2) / H_bldg")
println("      = $vz1 * $f_cR * $(city.b_basement + levers.R - levers.B/2) / $(city.H_bldg)")
println("      = $(cpp_numerator / city.H_bldg)")
println()

println("Difference:")
julia_rc = numerator / denominator
cpp_rc = cpp_numerator / city.H_bldg
println("  Julia: $julia_rc")
println("  C++:   $cpp_rc")
println("  Ratio: $(julia_rc / cpp_rc)")
println("  Percent diff: $((julia_rc - cpp_rc) / cpp_rc * 100)%")
