module  Visualization

    using GLMakie
    using SankeyMakie
    GLMakie.activate!()
    using ..Components
    using ..Variables

    export plot_P_Y, plot_Y, plot_P_Y_T, plot_scalar

    function plot_P_Y(input::Input , output::Output, var_name::String; 
                carrier_in::Union{Carrier,Nothing} = nothing,
                carrier_out::Union{Carrier,Nothing} = nothing
                )
        processes = collect(input.processes)
        if VARIABLES[var_name].sets != ("P","Y")
            error("the sets of $var_name is not equal to (P,Y)")
        end
            
        if carrier_in !== nothing
            processes = filter(p -> p.carrier_in == carrier_in, processes)       
        end
        if carrier_out !== nothing
            processes = filter(p -> p.carrier_out == carrier_out, processes)       
        end

        processes = sort(processes; by = p -> get(input.parameters["process_order"], p, 0))

        columns = Vector{Int}()
        values = Vector{Float64}()
        colors = Vector{String}()
        stacks = Vector{String}()

        for p in processes
            for y in input.years
                if (p,y) in keys(output[var_name])
                    push!(columns,Int(y))
                    push!(values, output[var_name][p,y])
                    push!(stacks, string(p))
                    push!(colors, input.parameters["process_color"][p])
                end
            end
        end

        fig = Figure()
        ax = Axis(
            fig[1,1],
            xticks = ([Int(y) for y in input.years], [string(y) for y in input.years]),
            xlabel = "Years",
            ylabel = "$(input.units[VARIABLES[var_name].unit].output)",
            title = "$var_name plot"
        )

        barplot!(
            ax,
            columns,
            values,
            stack = UInt64.(hash.(stacks)),
            color = colors
        )
        
        # Legend
        uniqueidx(v) = unique(i -> v[i], eachindex(v))
        indices = uniqueidx(stacks)
        labels = stacks[indices]
        elements = [PolyElement(polycolor =colors[i]) for i in indices]
        title = "Processes"

        Legend(fig[1,2], elements, labels, title)
        DataInspector(fig)
        display(fig)
        return fig
    end


    function plot_Y(input::Input , output::Output, var_name::String)
        if VARIABLES[var_name].sets != ("Y",)
            error("the sets of $var_name is not equal to (Y,)")
        end

        columns = Vector{Int}()
        values = Vector{Float64}()
        
        for y in input.years
            push!(columns, Int(y))
            push!(values, get(output[var_name],y,0))
        end

        fig = Figure()
        ax = Axis(
            fig[1,1],
            xticks = ([Int(y) for y in input.years], [string(y) for y in input.years]),
            xlabel = "Years",
            ylabel = "$(input.units[VARIABLES[var_name].unit].output)",
            title = "$var_name plot",
        )

        barplot!(ax,
            columns,
            values
        )
        DataInspector(fig)
        display(fig)
        return fig
    end


    function plot_P_Y_T(input::Input , output::Output, var_name::String, 
            year::Union{Year,Nothing} = nothing;
            carrier_in::Union{Carrier,Nothing} = nothing,
            carrier_out::Union{Carrier,Nothing} = nothing)
        
        processes = collect(input.processes)
        if VARIABLES[var_name].sets != ("P","Y","T")
            error("the sets of $var_name is not equal to (P,Y,T)")
        end
            
        if carrier_in !== nothing
            processes = filter(p -> p.carrier_in == carrier_in, processes)       
        end
        if carrier_out !== nothing
            processes = filter(p -> p.carrier_out == carrier_out, processes)       
        end

        processes = sort(processes; by = p -> get(input.parameters["process_order"], p, 0))

        diff_array = diff(Int.(input.timesteps))
        min_gap = minimum(diff_array)
        ticks = Vector{Int}()
        for (index,value) in enumerate(diff_array)
            if value > min_gap
                push!(ticks,index)
            end
        end


        fig = Figure()
        ax = Axis(
            fig[1, 1],
            xticks = (ticks, string.(ticks)),
            xlabel = "Timesteps",
            ylabel = "$(input.units[VARIABLES[var_name].unit].output)",
            title = "$var_name $(string(year)) plot",
        )

        xs = 1:length(input.timesteps)
        ys_high = zeros(length(input.timesteps))
        nonzero_processes = Vector{Process}()
        for p in processes
            ys_low = ys_high
            ys_high = Vector{Float64}()
            for t in input.timesteps
                value = get(output[var_name], (p, year, t), 0)
                push!(ys_high, value)
            end
            if any(ys_high .!= 0)
                push!(nonzero_processes, p)
                ys_high = ys_low .+ ys_high
                band!(ax, xs, ys_low, ys_high, color = input.parameters["process_color"][p])
            end
        end

        # Legend
        labels = [string(p) for p in nonzero_processes]
        elements = [PolyElement(polycolor =input.parameters["process_color"][p]) for p in nonzero_processes]
        title = "Processes"

        Legend(fig[1,2], elements, labels, title)

        display(fig)
        return fig
    end


    function plot_scalar(input::Input , output::Output, var_names::Vector{String})
        for var_name in var_names
            if VARIABLES[var_name].sets != ()
                error("the sets of $var_name is not equal to ()")
            end
        end

        columns = []
        values = []
        for (index,var_name) in enumerate(var_names)
            push!(columns, index)
            push!(values, output[var_name])
        end

        fig = Figure()
        ax = Axis(
            fig[1,1],
            xticks = (1:length(var_names), var_names), 
            title = "Scalar plot",
        )

        barplot!(ax,
            columns,
            values
        )
        DataInspector(fig)
        display(fig)
        return fig
    end

    function plot_sankey(input::Input, output::Output, year::Int)
        year = Year(year)
        processes = collect(input.processes)
        outflow = deepcopy(output["total_energy_out"])
        inflow = deepcopy(output["total_energy_in"])
        connections = Vector()
        for p1 in processes
            carrier_out = p1.carrier_out
            if carrier_out.name == "Dummy" #|| startswith(carrier_out.name,"Help")
                continue
            end
            for p2 in processes
                carrier_in = p2.carrier_in
                if carrier_out == carrier_in                
                    min = minimum((get(outflow,(p1,year),0),get(inflow,(p2,year),0)))
                    if min!= 0
                        push!(connections,(p1,p2,min))
                        outflow[p1,year] -= min
                        inflow[p2,year] -= min
                    end
                end
            end
        end
        used_processes = []
        for (p1,p2,value) in connections
            if !(p1 in used_processes)
                push!(used_processes, p1)
            end
            if !(p2 in used_processes)
                push!(used_processes, p2)
            end
        end
        used_processes_set = Set()
        for (p1,p2,value) in connections
            push!(used_processes_set,p1)
            push!(used_processes_set,p2)
        end
        used_process_vec = collect(used_processes_set)
        sort!(used_process_vec)
        temp = []
        for (p1,p2,value) in connections
            push!(temp,(findfirst(==(p1),used_process_vec),findfirst(==(p2),used_process_vec),value))
        end
        connections = temp
        labels = [p.name for p in used_process_vec]
        println(labels)
        
        sankey(connections,
        nodelabels = labels,
        nodecolor = [input.parameters["process_color"][p] for p in used_process_vec],
        linkcolor = SankeyMakie.Gradient(0.7),
        axis = hidden_axis(),
        figure = (; size = (1000, 500))
        )

    end

end