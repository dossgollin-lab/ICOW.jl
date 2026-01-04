using ICOW

city = CityParameters()

println("Julia Parameters:")
println("  D_startup: ", city.D_startup)
println("  s_dike: ", city.s_dike)
println("  w_d: ", city.w_d)
println("  c_d: ", city.c_d)
println("  W_city: ", city.W_city)
println("  D_city: ", city.D_city)
println("  Slope (W/D): ", city.W_city / city.D_city)

println("\nDike calculation for D=5:")
V = calculate_dike_volume(city, 5.0)
println("  Volume: ", V)
println("  Cost: ", calculate_dike_cost(city, 5.0))
