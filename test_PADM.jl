include("./src/core/CESM.jl")
include("./src/sensitivity/PADM.jl")
using .CESM
using .PADM

using GLMakie
GLMakie.activate!()


CONFIG_FILE_ADDRESS = "./examples/House/config.json"
input = CESM.Parser.parse_input(CONFIG_FILE_ADDRESS)
upper_values = PADM.PADM_alg(input)

using Serialization
serialize("upper_values.jls", upper_values)

upper_values = deserialize("upper_values.jls")


CHANGED_PROFILE_PROCESS = "Demand_Electricity"
CHANGED_CAPACITY_PROCESS = "PP_PV"
changed_profile_process =  first(filter(p -> p.name == CHANGED_PROFILE_PROCESS, input.processes))
changed_capacity_process = first(filter(p -> p.name == CHANGED_CAPACITY_PROCESS, input.processes))
PP_Wind = first(filter(p -> p.name == "PP_Wind", input.processes))

original_series = input.parameters["output_profile"][changed_profile_process]
manipulated_series = Dict(t => input.parameters["output_profile"][changed_profile_process][t] * (1+upper_values[t]) for t in input.timesteps)

original_data = [original_series[t] for t in input.timesteps]
PV_data = [input.parameters["availability_profile"][changed_capacity_process][t] for t in input.timesteps]
PV_data = PV_data ./ maximum(PV_data)
Wind_data = [input.parameters["availability_profile"][PP_Wind][t] for t in input.timesteps]
Wind_data = Wind_data ./ maximum(Wind_data)
scale = maximum(original_data)
original_data = original_data ./ scale
manipulated_data = [manipulated_series[t] for t in input.timesteps]
manipulated_data = manipulated_data ./ scale
lower_bound = original_data .* (1-0.1)
upper_bound = original_data .* (1+0.1)

x = 1:length(input.timesteps)
fig = Figure()
ax = Axis(fig[1, 1], title = "Two Vectors", xlabel = "Index", ylabel = "Value")

lines!(ax, x, manipulated_data, color = :red, label = "manipulated")
lines!(ax, x, original_data, color = :blue, label = "base")
lines!(ax, x, PV_data, color = :yellow, label = "PV")
lines!(ax, x, Wind_data, color = :purple, label = "Wind")
# lines!(ax, x, upper_bound, color = (:purple,0.2), label = "upper", linestyle = :dash, linewidth = 3)
# lines!(ax, x, lower_bound, color = (:purple,0.2), label = "lower", linestyle = :dash, linewidth = 3)


axislegend(ax, position = :rb)
fig