using ..Components
using ..Variables

function plot_P_Y(input::Input , output::Output, var_name::String, 
            carrier_in::Union{Carrier,Nothing} = nothing,
            carrier_out::Union{Carrier,Nothing} = nothing
            )
    processes = collect(input.processes)
    if variables[var_name].sets != ("P","Y")
        error("the sets of $var_name is not equal to (P,Y)")
    end
        
    if carrier_in !== nothing
        processes = filter(p -> p.carrier_in == carrier_in, processes)       
    end
    if carrier_out !== nothing
        processes = filter(p -> p.carrier_out == carrier_out, processes)       
    end

    processes = sort(processes; by = p -> get(input["process_order"], p, 0))

    columns = []
    values = []
    stacks = []
    colors = []

    for p in processes
        for y in input.years
            if (p,y) in output[var_name]
                push!(columns,int(y))
                push!(values, output[var_name][p,y])
                push!(stacks, str(p))
                push!(colors, input[process_color][p])
            end
        end
    end

    fig = Figure()
    ax = Axis(
        fig[1,1],
        xticks = ([int(y) for y in input.years], [str(y) for y in input.years]),
        title = "{var_name} plot",
    ),

    barplot!(ax,
        columns,
        values,
        stack = stacks,
        color = colors
    )

    # Legend
    labels = unique(stacks)
    elements = [PolyElement(polycolor = colors[i]) for i in 1:length(labels)]
    title = "Processes"

    Legend(fig[1,2], elements, labels, title)
end


function plot_Y(input::Input , output::Output, var_name::String)
    if variables[var_name].sets != ("Y",)
        error("the sets of $var_name is not equal to (Y,)")
    end

    columns = []
    values = []
    
    for y in input.years
        push!(columns, int(y))
        push!(values, get(output[var_name],y,0))
    end

    fig = Figure()
    ax = Axis(
        fig[1,1],
        xticks = ([int(y) for y in input.years], [str(y) for y in input.years]),
        title = "{var_name} plot",
    ),

    barplot!(ax,
        columns,
        values
    )
        
end


function plot_P_Y_T(input::Input , output::Output, var_name::String, 
        year::::Union{Year,Nothing} = nothing,
        carrier_in::Union{Carrier,Nothing} = nothing,
        carrier_out::Union{Carrier,Nothing} = nothing)
    processes = collect(input.processes)
    if variables[var_name].sets != ("P","Y","T")
        error("the sets of $var_name is not equal to (P,Y,T)")
    end
        
    if carrier_in !== nothing
        processes = filter(p -> p.carrier_in == carrier_in, processes)       
    end
    if carrier_out !== nothing
        processes = filter(p -> p.carrier_out == carrier_out, processes)       
    end

    processes = sort(processes; by = p -> get(input["process_order"], p, 0))

    f = Figure()
    Axis(f[1, 1])

    xs = 1:length(input.timesteps)
    ys_high = zeros(length(input.timesteps))
    for p in processes
        ys_low = ys_high
        ys_high = []
        for t in input.timesteps
            push!(ys_high, get(output[var_name], (p, y, t), 0))
        end
        ys_high = ys_low .+ ys_high
        band!(xs, ys_low, ys_high, color = output["process_color"][p])
    end
    fig
end


function plot_scalar(input::Input , output::Output, var_names::Tuple{String})
    for var_name in var_names
        if variables[var_name].sets != ()
            error("the sets of $var_name is not equal to ()")
        end
    end

    columns = []
    values = []
    for var_name in var_names
        push!(columns, var_name)
        push!(values, get(output,var_name,0))
    end

    fig = Figure()
    ax = Axis(
        fig[1,1],
        xticks = (var_names, var_names), # use collect if it didn't work
        title = "$var_name plot",
    ),

    barplot!(ax,
        columns,
        values
    )

end