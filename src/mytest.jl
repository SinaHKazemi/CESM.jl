using StatsPlots

x = rand(10,3)
println(x)
groupedbar(x, bar_position = :stack, bar_width=0.7)
