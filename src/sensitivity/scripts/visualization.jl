include("../../core/CESM.jl")
include("../utils.jl")
include("../PADM.jl")
include("./settings.jl")

using Serialization
using .Utils
using .Settings
using .CESM

using JuMP

# using GLMakie
# GLMakie.activate!()
using CairoMakie

function plot_PADM()
    linewidth = 1
    delta_values_vector = []
    for setting in  Settings.PADM_settings
        println("Visualizing for setting:")
        # print the hash of the setting
        println(Utils.logfile_name(setting))
        # change the input according to PALM
        delta_values = deserialize(joinpath(Settings.result_folder_path, "PADM_$(Utils.logfile_name(setting)).jls"))
        push!(delta_values_vector, delta_values)
    end
    for delta_values in delta_values_vector
        println("number of nonzero elements: ", count(t -> abs(delta_values[t]) > 0, keys(delta_values)))
    end
    setting = Settings.PADM_settings[1]
    # build the original model
    input = CESM.Parser.parse_input(setting.config_file)
    # run the original model
    output = CESM.Model.run_optimization(input)
    delta_values = delta_values_vector[1]
    
    manipulated_cp =  first(filter(p -> p.name == setting.manipulated_cp, input.processes))
    target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
    changed_input = deepcopy(input)
    for t in input.timesteps
        changed_input.parameters["output_profile"][manipulated_cp][t] *= (1 + delta_values[t])
    end
    model, vars, constraints = CESM.Model.build_model(changed_input)
    CESM.Model.optimize_model(model)
    changed_output = CESM.Model.get_output(changed_input, vars)

    println("Original capacity:")
    println(output["new_capacity"])
    println(output["total_energy_out"])
    println("Changed capacity:")
    println(changed_output["new_capacity"])
    println(changed_output["total_energy_out"])

    changed_input_20 = deepcopy(input)
    for t in input.timesteps
        changed_input_20.parameters["output_profile"][manipulated_cp][t] *= (1 + delta_values_vector[2][t])
    end
    model, vars, constraints = CESM.Model.build_model(changed_input_20)
    CESM.Model.optimize_model(model)
    changed_output_20 = CESM.Model.get_output(changed_input_20, vars)

    x = 1:length(input.timesteps)
    fig = Figure(size = (900, 600))
    i = 0 # row of the subplot
    axes = []

    # Plot demand
    ax = Axis(fig[i, 1], title = "Electricity Demand", ylabel = "kW")
    axes = push!(axes, ax)
    demand_changed_10 = [changed_output["energy_out_time"][manipulated_cp, input.years[end], t] for t in input.timesteps]
    demand_changed_20 = [get(changed_output_20["energy_out_time"], (manipulated_cp, input.years[end], t), 0) for t in input.timesteps]
    demand = [get(output["energy_out_time"], (manipulated_cp, input.years[end], t), 0) for t in input.timesteps]
    lines!(ax, x, demand_changed_10, color = :blue, label = "Changed (10%)", linestyle = :dot, linewidth=linewidth)
    lines!(ax, x, demand_changed_20 , color = :red, label = "Changed (20%)", linestyle = :dash, linewidth=linewidth)
    lines!(ax, x, demand, color = :blue, label = "Base")
    Legend(fig[i, 2], ax)

    # Plot PV
    i += 1
    target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
    ax = Axis(fig[i, 1], title = "PV", ylabel = "kW")
    axes = push!(axes, ax)
    cap = (8760/length(input.timesteps)) * get(output["active_capacity"],(target_cp,input.years[end]),0)
    cap_changed = (8760/length(input.timesteps)) * get(changed_output["active_capacity"],(target_cp,input.years[end]),0)
    PV = [get(output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    PV_changed = [get(changed_output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    lines!(ax, x, [input.parameters["availability_profile"][target_cp][t] * cap for t in input.timesteps], color = :orange, label = "Base Production Capacity", linewidth=linewidth, alpha=0.7)
    lines!(ax, x, [input.parameters["availability_profile"][target_cp][t] * cap_changed for t in input.timesteps], color = :orange, label = "Changed Production Capacity", linestyle = :dot, linewidth=linewidth, alpha=0.7)
    lines!(ax, x, PV, color = :red, label = "Base Production", linewidth=linewidth, alpha=0.7)
    lines!(ax, x, PV_changed, color = :red, label = "Changed Production", linestyle = (:dot,:dense), linewidth=linewidth, alpha=0.7)
    Legend(fig[i, 2], ax)

    
    # if length(filter(p -> p.name == "PP_Wind", input.processes)) > 0
    #     i += 1
    #     wind_cp = first(filter(p -> p.name == "PP_Wind", input.processes))
    #     ax = Axis(fig[i, 1], title = "Wind", ylabel = "kW")
    #     axes = push!(axes, ax)
    #     Wind = [get(output["energy_out_time"], (wind_cp, input.years[end], t), 0) for t in input.timesteps]
    #     Wind_changed = [get(changed_output["energy_out_time"], (wind_cp, input.years[end], t), 0) for t in input.timesteps]
    #     cap = (8760/length(input.timesteps)) * get(output["active_capacity"],(wind_cp,input.years[end]),0)
    #     cap_changed = (8760/length(input.timesteps)) * get(changed_output["active_capacity"],(wind_cp,input.years[end]),0)
    #     lines!(ax, x, Wind, color = :blue, label = "Production")
    #     lines!(ax, x, Wind_changed, color = :red, label = "Changed Production", linestyle = :dot)
    #     lines!(ax, x, [input.parameters["availability_profile"][wind_cp][t] * cap for t in input.timesteps], color = :blue, label = "Availability", linestyle = :dash)
    #     lines!(ax, x, [input.parameters["availability_profile"][wind_cp][t] * cap_changed for t in input.timesteps], color = :red, label = "Changed Availability", linestyle = :dash)
    #     Legend(fig[i, 2], ax)
    # end

    # i += 1
    # ax = Axis(fig[i, 1], title = "Electricity Import", ylabel = "kW")
    # axes = push!(axes, ax)
    # import_cp = first(filter(p -> p.name == "Import_Electricity", input.processes))
    # elec_import = [get(output["energy_out_time"], (import_cp, input.years[end], t), 0) for t in input.timesteps]
    # elec_import_changed = [get(changed_output["energy_out_time"], (import_cp, input.years[end], t), 0) for t in input.timesteps]
    # lines!(ax, x, elec_import , color = :brown, label = "Base")
    # lines!(ax, x, elec_import_changed , color = :gray, label = "Changed", linestyle = :dot)
    # Legend(fig[i, 2], ax)


    # band!(ax, x, PV, max.(PV, PV_changed), color=(:red, 0.5))
    
    # axislegend(ax, position = :lt)
    axes[end].xlabel = "Time Steps"
    ticks = [index for (index,t) in enumerate(input.timesteps) if abs(delta_values[t]) > 1e-2 && abs(delta_values[t]) > abs(delta_values[t-1]) && abs(delta_values[t]) > abs(delta_values[t+1])]
    linkxaxes!(axes...)
    for ax in axes
        xlims!(ax, 1, length(input.timesteps))
        ax.xticks = (ticks)
        ax.xticklabelrotation = 3.14/4
    end
    
    save("figure_PADM.pdf", fig, pdf_version="1.4")
    # fig
    # display(fig)
end

function plot_PALM()
    linewidth = 1
    delta_values_vector = []
    for setting in  Settings.PALM_settings
        println("Visualizing for setting:")
        # print the hash of the setting
        println(Utils.logfile_name(setting))
        # change the input according to PALM
        delta_values = deserialize(joinpath(Settings.result_folder_path, "PALM_$(Utils.logfile_name(setting)).jls"))
        push!(delta_values_vector, delta_values)
    end
    for delta_values in delta_values_vector
        println("number of nonzero elements: ", count(t -> abs(delta_values[t]) > 0, keys(delta_values)))
    end
    setting = Settings.PALM_settings[1]
    # build the original model
    input = CESM.Parser.parse_input(setting.config_file)
    # run the original model
    output = CESM.Model.run_optimization(input)
    delta_values = delta_values_vector[1]
    
    manipulated_cp =  first(filter(p -> p.name == setting.manipulated_cp, input.processes))
    target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
    changed_input = deepcopy(input)
    for t in input.timesteps
        changed_input.parameters["availability_profile"][manipulated_cp][t] *= (1 + delta_values[t])
    end
    model, vars, constraints = CESM.Model.build_model(changed_input)
    CESM.Model.optimize_model(model)
    changed_output = CESM.Model.get_output(changed_input, vars)

    println("Original capacity:")
    println(output["new_capacity"])
    println(output["total_energy_out"])
    println("Changed capacity:")
    println(changed_output["new_capacity"])
    println(changed_output["total_energy_out"])

    changed_input_20 = deepcopy(input)
    for t in input.timesteps
        changed_input_20.parameters["availability_profile"][manipulated_cp][t] *= (1 + delta_values_vector[2][t])
    end
    # model, vars, constraints = CESM.Model.build_model(changed_input_20)
    # CESM.Model.optimize_model(model)
    # changed_output_20 = CESM.Model.get_output(changed_input_20, vars)

            
    println("max value delta 10%: ", maximum([abs(delta_values[t]) for t in input.timesteps]))
    println("max value delta 20%: ", maximum([abs(delta_values_vector[2][t]) for t in input.timesteps]))
    # if length(filter(p -> p.name == "PP_Wind", input.processes)) > 0
    #     wind_cp = first(filter(p -> p.name == "PP_Wind", input.processes))
    # else
    #     wind_cp = nothing
    # end
    x = 1:length(input.timesteps)
    fig = Figure(size = (900, 600))
    i = 1 # row of the subplot
    axes = []
    target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
    demand_cp = first(filter(p -> p.name == "Demand_Electricity", input.processes))

    ax = Axis(fig[i, 1], title = "Electricity Demand and PV Production", ylabel = "kW")
    axes = push!(axes, ax)

    demand = [get(output["energy_out_time"], (demand_cp, input.years[end], t), 0) for t in input.timesteps]
    PV = [get(output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    PV_changed = [get(changed_output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    
    # if wind_cp !== nothing
    #     Wind = [get(output["energy_out_time"], (wind_cp, input.years[end], t), 0) for t in input.timesteps]
    #     lines!(ax, x, Wind .+ PV, color = :red, label = "PV + Wind Base")
    #     Wind_changed = [get(changed_output["energy_out_time"], (manipulated_cp, input.years[end], t), 0) for t in input.timesteps]
    #     lines!(ax, x, PV_changed .+ Wind_changed, color = :green, label = "PV + Demand Base", linestyle = :dot)
    # end
    # lines!(ax, x, demand, color = :blue, label = "Demand")
    # Legend(fig[i, 2], ax)

    # i += 1
    
    # ax = Axis(fig[i, 1], title = "PV", ylabel = "kW")
    # axes = push!(axes, ax)
    sum_cap = sum(get(output["new_capacity"],(target_cp,y),0) for y in input.years if Int(y) <= setting.last_year)

    println([get(output["new_capacity"],(target_cp,y),0) for y in input.years])
    println([get(changed_output["new_capacity"],(target_cp,y),0) for y in input.years])
    sum_cap_changed = sum(get(changed_output["new_capacity"],(target_cp,y),0) for y in input.years if Int(y) <= setting.last_year)
    println("Base PV capacity: $sum_cap, Changed PV capacity: $sum_cap_changed, increase: $((sum_cap_changed/sum_cap)-1)")
    cap = (8760/length(input.timesteps)) * (get(output["active_capacity"],(target_cp,input.years[end]),0))
    cap_changed = (8760/length(input.timesteps)) * (get(changed_output["active_capacity"],(target_cp,input.years[end]),0))
    PV = [get(output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    PV_changed = [get(changed_output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    lines!(ax, x, demand , color = :blue, label = "Demand", alpha=0.7, linewidth=linewidth)
    lines!(ax, x, [input.parameters["availability_profile"][target_cp][t] * cap for t in input.timesteps], color = :orange, label = "Base PV Production Capacity", linestyle = :solid, alpha=0.7, linewidth=linewidth)
    lines!(ax, x, [changed_input.parameters["availability_profile"][target_cp][t] * cap_changed for t in input.timesteps], color = :orange, label = "Changed PV Production Capacity", linestyle = :dot, alpha=0.7, linewidth=linewidth)
    lines!(ax, x, PV, color = :red, label = "Base PV Production", alpha=0.7, linewidth=linewidth)
    lines!(ax, x, PV_changed, color = :red, label = "Changed PV Production", linestyle = (:dot,:dense), alpha=0.7, linewidth=linewidth)
    Legend(fig[i, 2], ax)

    
    # if wind_cp !== nothing
    #     i += 1
    #     ax = Axis(fig[i, 1], title = "Wind", ylabel = "kW")
    #     axes = push!(axes, ax)
    #     Wind = [get(output["energy_out_time"], (wind_cp, input.years[end], t), 0) for t in input.timesteps]
    #     Wind_changed = [get(changed_output["energy_out_time"], (wind_cp, input.years[end], t), 0) for t in input.timesteps]
    #     cap = (8760/length(input.timesteps)) * get(output["active_capacity"],(wind_cp,input.years[end]),0)
    #     cap_changed = (8760/length(input.timesteps)) * get(changed_output["active_capacity"],(wind_cp,input.years[end]),0)
    #     lines!(ax, x, Wind, color = :blue, label = "Production")
    #     lines!(ax, x, Wind_changed, color = :red, label = "Changed Production", linestyle = :dot)
    #     lines!(ax, x, [input.parameters["availability_profile"][wind_cp][t] * cap for t in input.timesteps], color = :blue, label = "Availability", linestyle = :dash)
    #     lines!(ax, x, [changed_input.parameters["availability_profile"][wind_cp][t] * cap_changed for t in input.timesteps], color = :red, label = "Changed Availability", linestyle = :dash)
    #     Legend(fig[i, 2], ax)
    # end

    i += 1
    ax = Axis(fig[i, 1], title = "PV Availability", ylabel = "Availability")
    axes = push!(axes, ax)
    lines!(ax, x, [input.parameters["availability_profile"][manipulated_cp][t] for t in input.timesteps], color = :violetred1, label = "Base Availability", linewidth=linewidth, alpha=0.7)
    lines!(ax, x, [changed_input.parameters["availability_profile"][manipulated_cp][t] for t in input.timesteps], color = :violetred1, label = "Changed Availability (10%)", linestyle = (:dot,:dense), linewidth=linewidth, alpha=0.7)
    # lines!(ax, x, [changed_input_20.parameters["availability_profile"][target_cp][t] for t in input.timesteps], color = :red, label = "Changed PV (20%)", linestyle = :dash, linewidth=linewidth, alpha=0.7)
    lines!(ax, x, [delta_values[t] for t in input.timesteps], color = :purple, linestyle = :solid, label = L"\delta (10\%)", linewidth=linewidth, alpha=0.5)
    lines!(ax, x, [delta_values_vector[2][t] for t in input.timesteps], color = :purple, label = L"\delta (20\%)", linestyle = :dash, linewidth=linewidth, alpha=0.5)
    # lines!(ax, x, [changed_input.parameters["availability_profile"][target_cp][t] for t in input.timesteps], color = :purple, label = "PV")
    ax.yticks =  [-.2,-.1,0,.2, .5,1]
    Legend(fig[i, 2], ax)


    # band!(ax, x, PV, max.(PV, PV_changed), color=(:red, 0.5))
    
    # axislegend(ax, position = :lt)
    axes[end].xlabel = "Time Steps"
    ticks = [index for (index,t) in enumerate(input.timesteps) if abs(delta_values[t]) > 1e-2 && abs(delta_values[t]) > abs(delta_values[t-1]) && abs(delta_values[t]) > abs(delta_values[t+1])]
    linkxaxes!(axes...)
    for ax in axes
        xlims!(ax, 1, length(input.timesteps))
        ax.xticks = (ticks)
        ax.xticklabelrotation = 3.14/4
    end
    
    save("figure_PALM.pdf", fig, pdf_version="1.4")
    # fig
    # display(fig)
end

function plot_PALM_Wind()
    linewidth = 1
    delta_values_vector = []
    for setting in  Settings.PALM_settings
        println("Visualizing for setting:")
        # print the hash of the setting
        println(Utils.logfile_name(setting))
        # change the input according to PALM
        delta_values = deserialize(joinpath(Settings.result_folder_path, "PALM_$(Utils.logfile_name(setting)).jls"))
        push!(delta_values_vector, delta_values)
    end
    for delta_values in delta_values_vector
        println("number of nonzero elements: ", count(t -> abs(delta_values[t]) > 0, keys(delta_values)))
    end
    setting = Settings.PALM_settings[1]
    # build the original model
    input = CESM.Parser.parse_input(setting.config_file)
    # run the original model
    output = CESM.Model.run_optimization(input)
    delta_values = delta_values_vector[1]
    
    manipulated_cp =  first(filter(p -> p.name == setting.manipulated_cp, input.processes))
    target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
    changed_input = deepcopy(input)
    for t in input.timesteps
        changed_input.parameters["availability_profile"][manipulated_cp][t] *= (1 + delta_values[t])
    end
    model, vars, constraints = CESM.Model.build_model(changed_input)
    CESM.Model.optimize_model(model)
    changed_output = CESM.Model.get_output(changed_input, vars)

    println("Original capacity:")
    println(output["new_capacity"])
    println(output["total_energy_out"])
    println("Changed capacity:")
    println(changed_output["new_capacity"])
    println(changed_output["total_energy_out"])

    changed_input_20 = deepcopy(input)
    for t in input.timesteps
        changed_input_20.parameters["availability_profile"][manipulated_cp][t] *= (1 + delta_values_vector[2][t])
    end
    # model, vars, constraints = CESM.Model.build_model(changed_input_20)
    # CESM.Model.optimize_model(model)
    # changed_output_20 = CESM.Model.get_output(changed_input_20, vars)

            
    println("max value delta 10%: ", maximum([abs(delta_values[t]) for t in input.timesteps]))
    println("max value delta 20%: ", maximum([abs(delta_values_vector[2][t]) for t in input.timesteps]))
    # if length(filter(p -> p.name == "PP_Wind", input.processes)) > 0
    #     wind_cp = first(filter(p -> p.name == "PP_Wind", input.processes))
    # else
    #     wind_cp = nothing
    # end
    x = 1:length(input.timesteps)
    fig = Figure(size = (900, 900))
    i = 1 # row of the subplot
    axes = []
    target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
    demand_cp = first(filter(p -> p.name == "Demand_Electricity", input.processes))

    ax = Axis(fig[i, 1], title = "Electricity Demand and Production", ylabel = "kW")
    axes = push!(axes, ax)

    demand = [get(output["energy_out_time"], (demand_cp, input.years[end], t), 0) for t in input.timesteps]
    PV = [get(output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    PV_changed = [get(changed_output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    
    Wind = [get(output["energy_out_time"], (manipulated_cp, input.years[end], t), 0) for t in input.timesteps]
    Wind_changed = [get(changed_output["energy_out_time"], (manipulated_cp, input.years[end], t), 0) for t in input.timesteps]


    lines!(ax, x, Wind .+ PV, color = :green, label = "Base PV + Wind Production", linewidth=linewidth, alpha=0.7)
    lines!(ax, x, PV_changed .+ Wind_changed, color = :green, label = "Changed PV + Wind Production", linestyle = :dot, linewidth=linewidth, alpha=0.7)
    lines!(ax, x, demand , color = :blue, label = "Demand", alpha=1, linewidth=linewidth)
    Legend(fig[i, 2], ax)



    i += 1
    ax = Axis(fig[i, 1], title = "PV", ylabel = "kW")
    axes = push!(axes, ax)
    # sum_cap = sum(get(output["new_capacity"],(target_cp,y),0) for y in input.years if Int(y) <= setting.last_year)
    # println([get(output["new_capacity"],(target_cp,y),0) for y in input.years])
    # println([get(changed_output["new_capacity"],(target_cp,y),0) for y in input.years])
    # sum_cap_changed = sum(get(changed_output["new_capacity"],(target_cp,y),0) for y in input.years if Int(y) <= setting.last_year)
    # println("Base PV capacity: $sum_cap, Changed PV capacity: $sum_cap_changed, increase: $((sum_cap_changed/sum_cap)-1)")
    cap = (8760/length(input.timesteps)) * (get(output["active_capacity"],(target_cp,input.years[end]),0))
    cap_changed = (8760/length(input.timesteps)) * (get(changed_output["active_capacity"],(target_cp,input.years[end]),0))
    PV = [get(output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    PV_changed = [get(changed_output["energy_out_time"], (target_cp, input.years[end], t), 0) for t in input.timesteps]
    lines!(ax, x, [input.parameters["availability_profile"][target_cp][t] * cap for t in input.timesteps], color = :orange, label = "Base Production Capacity", linestyle = :solid, alpha=0.7, linewidth=linewidth)
    lines!(ax, x, [changed_input.parameters["availability_profile"][target_cp][t] * cap_changed for t in input.timesteps], color = :orange, label = "Changed Production Capacity", linestyle = :dot, alpha=0.7, linewidth=linewidth)
    lines!(ax, x, PV, color = :red, label = "Base Production", alpha=0.7, linewidth=linewidth)
    lines!(ax, x, PV_changed, color = :red, label = "Changed Production", linestyle = (:dot,:dense), alpha=0.7, linewidth=linewidth)
    Legend(fig[i, 2], ax)

    

    i += 1
    ax = Axis(fig[i, 1], title = "Wind", ylabel = "kW")
    axes = push!(axes, ax)
    Wind = [get(output["energy_out_time"], (manipulated_cp, input.years[end], t), 0) for t in input.timesteps]
    Wind_changed = [get(changed_output["energy_out_time"], (manipulated_cp, input.years[end], t), 0) for t in input.timesteps]
    cap = (8760/length(input.timesteps)) * get(output["active_capacity"],(manipulated_cp,input.years[end]),0)
    cap_changed = (8760/length(input.timesteps)) * get(changed_output["active_capacity"],(manipulated_cp,input.years[end]),0)
    lines!(ax, x, Wind, color = :navyblue, label = "Production", linewidth=linewidth, alpha=0.7)
    lines!(ax, x, Wind_changed, color = :navyblue, label = "Changed Production", linestyle = :dot, linewidth=linewidth, alpha=0.7)
    lines!(ax, x, [input.parameters["availability_profile"][manipulated_cp][t] * cap for t in input.timesteps], color = :orange, label = "Production Capacity", linewidth=linewidth, alpha=0.7)
    lines!(ax, x, [changed_input.parameters["availability_profile"][manipulated_cp][t] * cap_changed for t in input.timesteps], color = :orange, label = "Changed Production Capacity", linestyle = :dot, linewidth=linewidth, alpha=0.7)
    Legend(fig[i, 2], ax)


    i += 1
    ax = Axis(fig[i, 1], title = "Wind Availability", ylabel = "Availability")
    axes = push!(axes, ax)
    lines!(ax, x, [input.parameters["availability_profile"][manipulated_cp][t] for t in input.timesteps], color = :violetred1, label = "Base Availability", linewidth=linewidth, alpha=0.7)
    lines!(ax, x, [changed_input.parameters["availability_profile"][manipulated_cp][t] for t in input.timesteps], color = :violetred1, label = "Changed Availability (10%)", linestyle = (:dot,:dense), linewidth=linewidth, alpha=0.7)
    # lines!(ax, x, [changed_input_20.parameters["availability_profile"][target_cp][t] for t in input.timesteps], color = :red, label = "Changed PV (20%)", linestyle = :dash, linewidth=linewidth, alpha=0.7)
    lines!(ax, x, [delta_values[t] for t in input.timesteps], color = :purple, linestyle = :solid, label = L"\delta (10\%)", linewidth=linewidth, alpha=0.5)
    lines!(ax, x, [delta_values_vector[2][t] for t in input.timesteps], color = :purple, label = L"\delta (20\%)", linestyle = :dash, linewidth=linewidth, alpha=0.5)
    # lines!(ax, x, [changed_input.parameters["availability_profile"][target_cp][t] for t in input.timesteps], color = :purple, label = "PV")
    Legend(fig[i, 2], ax)
    ax.yticks =  [-.2,-.1,0,.2, .5, 1]


    
    # axislegend(ax, position = :lt)
    axes[end].xlabel = "Time Steps"
    ticks = [index for (index,t) in enumerate(input.timesteps) if abs(delta_values[t]) > 1e-2 && abs(delta_values[t]) > abs(delta_values[t-1]) && abs(delta_values[t]) > abs(delta_values[t+1])]
    linkxaxes!(axes...)
    for ax in axes
        xlims!(ax, 1, length(input.timesteps))
        ax.xticks = (ticks)
        ax.xticklabelrotation = 3.14/4
    end
    
    save("figure_PALM_Wind.pdf", fig, pdf_version="1.4")
    # fig
    # display(fig)
end



function visualize(name::String)
    if name == "PADM"
        settings = Settings.PADM_settings
    elseif name == "PALM"
        settings = Settings.PALM_settings
    else
        error("Unknown method name: $name")
    end
    for setting in settings[1:1]
        println("Visualizing for setting:")
        # print the hash of the setting
        println(Utils.logfile_name(setting))
        # build the original model
        input = CESM.Parser.parse_input(setting.config_file)
        # run the original model
        output = CESM.Model.run_optimization(input)
        # output = nothing
        # change the input according to PALM
        delta_values = deserialize(joinpath(Settings.result_folder_path, "$(name)_$(Utils.logfile_name(setting)).jls"))
        if delta_values === nothing
            println("No delta values found for setting $(Utils.logfile_name(setting)), skipping...")
            continue
        end
        manipulated_cp =  first(filter(p -> p.name == setting.manipulated_cp, input.processes))
        target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
        changed_input = deepcopy(input)
        for t in input.timesteps
            delta_values[t]
            changed_input.parameters[if name == "PADM" "output_profile" else "availability_profile" end][manipulated_cp][t] *= (1 + delta_values[t])
        end
        # run the changed model
        model, vars, constraints = CESM.Model.build_model(changed_input)
        CESM.Model.optimize_model(model)
        changed_output = CESM.Model.get_output(changed_input, vars)


        # changed_output = CESM.Model.run_optimization(changed_input)
        # changed_output = nothing
        if name == "PADM"
            plot_PADM(input, output, changed_input, changed_output, setting, delta_values)
        elseif name == "PALM"
            plot_PALM(input, output, changed_input, changed_output, setting, delta_values)
        end
    end
end

# visualize("PADM")
plot_PADM()
# plot_PALM()
# plot_PALM_Wind()


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


# CHANGED_PROFILE_PROCESS = "Demand_Electricity"
# CHANGED_CAPACITY_PROCESS = "PP_PV"
# changed_profile_process =  first(filter(p -> p.name == CHANGED_PROFILE_PROCESS, input.processes))
# changed_capacity_process = first(filter(p -> p.name == CHANGED_CAPACITY_PROCESS, input.processes))



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