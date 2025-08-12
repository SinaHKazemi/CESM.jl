function plot(model_data, var_name, co=nothing, y=nothing)
    input = model_data["input"]
    output = model_data["output"]
    if "CP" in variables[var_name].sets
        
    end
    if variables[var_name].sets == ("P","Y","T")

    elseif variables[var_name].sets == ("P","Y")
    elseif variables[var_name].sets == ("Y")
    elseif variables[var_name].sets == ()
    else
    
end


function bar_plot(input, output, var_name, carrier_in=nothing, carrier_out=nothing)
    if Set(variables[var_name].sets) != Set(("P","Y"))
        throw(InvalidParameterError("bar_plot only supports variables with sets P and Y, $(var_name) is indexed by $(variables[var_name].sets)"))
    end
    # filter processes based on carrier_in and carrier_out
    processes = [p for p in input.processes]
    if carrier_in !== nothing
        processes = [p for p in processes if input.carrier_in[p] == carrier_in]
    end
    if carrier_out !== nothing
        processes = [p for p in processes if input.carrier_out[p] == carrier_out]
    end
    
    for p in processes
        for y in input.years
            plot_data = []
        end
    end

    
end