module MGAAnalysis

using Serialization
using ...CESM.Model
using ...CESM.Components
using ..MGAFunctions

export analyze_mga_results

"""
    compute_objective_value(input::Input, output::Output, obj_name::String)

Calculates the numeric value of an MGA objective for a given Output.
This replicates the logic found in MGAFunctions but applies it to numeric data.
"""
function compute_objective_value(input::Input, output::Output, obj_name::String)
    if haskey(MGA_OBJECTIVE_DEFS, obj_name)
        return MGA_OBJECTIVE_DEFS[obj_name].func(input, output)
    else
        @warn "Objective '$obj_name' not found in registry."
        return NaN
    end
end

"""
    analyze_mga_results(input::Input, results_dir::String)

Loads all .jls files in `results_dir`, calculates the value of every MGA objective 
for each one, and returns a Dictionary of Dictionaries.
"""
function analyze_mga_results(input::Input, results_dir::String)
    files = filter(f -> endswith(f, ".jls"), readdir(results_dir))
    
    # Get the list of objective names from the registry
    obj_names = collect(keys(MGA_OBJECTIVE_DEFS))
    
    results = Dict{String, Dict{String, Float64}}()

    for file in files
        path = joinpath(results_dir, file)
        output = deserialize(path)
        
        case_name = replace(file, ".jls" => "")
        results[case_name] = Dict{String, Float64}()
        
        for name in obj_names
            results[case_name][name] = compute_objective_value(input, output, name)
        end
    end

    return results
end

end
