include("../../core/CESM.jl")
include("../utils.jl")
include("../PADM.jl")


using Serialization
using .Utils

using GLMakie
GLMakie.activate!()
# using CairoMakie


log_folder_path = "./logs"
result_folder_path = "./results"

settings = [
    Utils.Setting(
        config_file = "./examples/House/config.json",
        manipulation_bound = 0.1,
        manipulated_cp = "Demand_Electricity",
        target_cp = "PP_PV",
        target_change = 0.1,
        init_mu = 1.0,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path
    ),
    Utils.Setting(
        config_file = "./examples/House/config.json",
        manipulation_bound = 0.05,
        manipulated_cp = "Demand_Electricity",
        target_cp = "PP_PV",
        target_change = 0.3,
        init_mu = 1.0,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path
    ),
    Utils.Setting(
        config_file = "./examples/House/config.json",
        manipulation_bound = 0.05,
        manipulated_cp = "Demand_Electricity",
        target_cp = "PP_PV",
        target_change = 0.4,
        init_mu = 1.0,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path
    ),
    Utils.Setting(
        config_file = "./examples/House/config.json",
        manipulation_bound = 0.05,
        manipulated_cp = "Demand_Electricity",
        target_cp = "PP_PV",
        target_change = 0.5,
        init_mu = 1.0,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path
    )
]


for setting in settings
    # find the name of the file
    # build the original model
    input = CESM.Parser.parse_input(setting.config_file)
    # run the original model
    # output = CESM.Model.run_optimization(input)
    # change the input according to PALM
    println(Utils.logfile_name(setting))
    # continue
    println(joinpath(result_folder_path, "PADM_$(Utils.logfile_name(setting)).jls"))
    delta_values = deserialize(joinpath(result_folder_path, "PADM_$(Utils.logfile_name(setting)).jls"))
    # println(maximum(values(delta_values)))
    if delta_values === nothing
        continue
    end
    manipulated_cp =  first(filter(p -> p.name == setting.manipulated_cp, input.processes))
    println(manipulated_cp)
    target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
    changed_input = deepcopy(input)
    for t in input.timesteps
        delta_values[t]
        changed_input.parameters["output_profile"][manipulated_cp][t] *= (1 + delta_values[t])
    end
    # run the changed model
    changed_output = CESM.Model.run_optimization(changed_input)
    break

end

# serialize("upper_values_b.jls", upper_values)
# serialize("output_b.jls", output)
# serialize("changed_output_b.jls", changed_output)

# upper_values = deserialize("upper_values.jls")
# output = deserialize("output.jls")
# changed_output = deserialize("changed_output.jls")

# upper_values = deserialize("upper_values_b.jls")
# output = deserialize("output_b.jls")
# changed_output = deserialize("changed_output_b.jls")


# upper_values_10 = deserialize("upper_values_PV_10.jls")
# upper_values_15 = deserialize("upper_values_PV_15_12.jls")


CHANGED_PROFILE_PROCESS = "Demand_Electricity"
CHANGED_CAPACITY_PROCESS = "PP_PV"
changed_profile_process =  first(filter(p -> p.name == CHANGED_PROFILE_PROCESS, input.processes))
changed_capacity_process = first(filter(p -> p.name == CHANGED_CAPACITY_PROCESS, input.processes))



# PP_Wind = first(filter(p -> p.name == "PP_Wind", input.processes))

# original_series = input.parameters["output_profile"][changed_profile_process]
# manipulated_series_10 = Dict(t => input.parameters["output_profile"][changed_profile_process][t] * (1+upper_values_10[t]) for t in input.timesteps)
# manipulated_series_15 = Dict(t => input.parameters["output_profile"][changed_profile_process][t] * (1+upper_values_15[t]) for t in input.timesteps)

# original_data = [original_series[t] for t in input.timesteps]
# PV_data = [input.parameters["availability_profile"][changed_capacity_process][t] for t in input.timesteps]
# PV_data = PV_data ./ maximum(PV_data)
# Wind_data = [input.parameters["availability_profile"][PP_Wind][t] for t in input.timesteps]
# Wind_data = Wind_data ./ maximum(Wind_data)
# scale = maximum(original_data)
# original_data = original_data ./ scale
# manipulated_data_10 = [manipulated_series_10[t] for t in input.timesteps]
# manipulated_data_10 = manipulated_data_10 ./ scale
# manipulated_data_15 = [manipulated_series_15[t] for t in input.timesteps]
# manipulated_data_15 = manipulated_data_15 ./ scale
# lower_bound = original_data .* (1-0.1)
# upper_bound = original_data .* (1+0.1)

# demand_changed = [changed_output["energy_out_time"][changed_profile_process, CESM.Components.Year(2030), t] for t in input.timesteps]
# demand = [output["energy_out_time"][changed_profile_process, CESM.Components.Year(2030), t] for t in input.timesteps]
# PV_production = [get(output["energy_out_time"],(changed_capacity_process, CESM.Components.Year(2030), t), 0) for t in input.timesteps]
# PV_production_changed = [get(changed_output["energy_out_time"],(changed_capacity_process, CESM.Components.Year(2030), t), 0) for t in input.timesteps]
# PV_capacity = (8760/1344) * output["active_capacity"][changed_capacity_process, CESM.Components.Year(2030)] .* PV_data
# PV_capacity_changed = (8760/1344) * changed_output["active_capacity"][changed_capacity_process, CESM.Components.Year(2030)] .* PV_data

# println(demand_changed)

# x = 1:length(input.timesteps)
# fig = Figure()
# ax = Axis(fig[1, 1], title = "Two Vectors", xlabel = "Index", ylabel = "Value")
# ylims!(ax, 0, maximum(demand)*1.1)

# lines!(ax, x, manipulated_data_10, color = :red, label = "manipulated")
# lines!(ax, x, manipulated_data_15, color = :green, label = "manipulated 15%")
# lines!(ax, x, original_data, color = :blue, label = "base")
# lines!(ax, x, PV_data, color = :yellow, label = "PV")
# lines!(ax, x, Wind_data, color = :purple, label = "Wind")
# lines!(ax, x, upper_bound, color = (:purple,0.2), label = "upper", linestyle = :dash, linewidth = 3)
# lines!(ax, x, lower_bound, color = (:purple,0.2), label = "lower", linestyle = :dash, linewidth = 3)

# lines!(ax, x, PV_production_changed, color = :orange, label = "PV production changed")
# lines!(ax, x, PV_production, color = :blue, label = "PV production")
# lines!(ax, x, demand_changed, color = :red, label = "manipulated")
# lines!(ax, x, demand, color = :green, label = "base")

# lines!(ax, x, PV_capacity_changed, color = :purple, label = "PV capacity changed", linestyle = :dash)
# lines!(ax, x, PV_capacity, color = :brown, label = "PV capacity", linestyle = :dash)

# axislegend(ax, position = :rb)
# fig
# save("first_figure.svg", fig)