module Parse

using JSON

export parse

struct ParseError <: Exception
    msg::String
end

type_dict = Dict(
    "Float" => Float64,
    "Integer" => Int,
    "Boolean" => Bool
)

function parse_input(path::AbstractString)::Dict
    fullpath = abspath(path)  # normalize to absolute path
    base_path = dirname(fullpath)

    if !isfile(fullpath)
        error("JSON file not found: $fullpath")
    end

    open(fullpath, "r") do io
        data = JSON.parse(read(io, String))
    end
    
    input = Dict()
    input["units"] = data["units"]
    input["timesteps"] = parse_timesteps(data["timesteps"])
    input["years"] = parse_years(data["Units"])
    input["carriers"] = parse_carriers(data["carriers"])
    input["processes"] = parse_processes(data["processes"], input["carriers"])
    input["parameters"] = parse_parameters(data, input, base_path)
    return input
end

function parse_data_file(path::AbstractString, base_path::AbstractString, ::Type{T}) where {T}
    # Use base_path if path is relative
    fullpath = isabspath(path) ? path : joinpath(base_path, path)

    # Normalize to absolute path
    fullpath = abspath(fullpath)

    # Validate file existence
    if !isfile(fullpath)
        error("File not found: $fullpath")
    end

    data = T[]

    open(fullpath, "r") do io
        for line in eachline(io)
            # Skip full-line comments
            if occursin(r"^\s*#", line)
                continue
            end

            # Split on space, tab, comma, etc.
            tokens = split(line, r"[,\s]+", keepempty=false)

            for token in tokens
                try
                    push!(data, parse(T, token))
                catch
                    error("Invalid input: $token")
                end
            end
        end
    end

    return data
end

function get_vector_or_file(x, ::Type{T}) where {T}
    if isa(x, Vector{T})
        return x
    elseif isa(x, AbstractString)
        return parse_data_file(x, pwd(), T)
    else
        error("Input must be either Vector{$T} or a file path string.")
    end
end

function validate_temporal_sequence(values::Vector{Int})
    if ! (length(values) == length(unique(indices)))
        error("Duplicate values found in the vector")
    elseif ! all(values .> 0)
        error("Negative values found in the vector")
    elseif ! all(diff(values) .> 0)
        error("Non-increasing values found in the vector")
    end
end

function parse_timesteps(timesteps_data::Union{Vector,AbstractString})::Vector{Int}
    timesteps = get_vector_or_file(timesteps_data, Int)
    validate_temporal_sequence(timesteps)
    return timesteps
end

function parse_years(years_data::Union{Vector,AbstractString})::Vector{Int}
    years = get_vector_or_file(years_data, Int)
    validate_temporal_sequence(years)
    return years
end

function parse_carriers(data::Dict)::Dict{String}
    return(Vector{String}(keys(data["carriers"])))
end

function parse_processes(data::Dict, carriers::Vector{String})::Dict{String, Dict{String, String}}
    processes = Dict{String, Dict{String, String}}()
    for (process_name, process_data) in data
        if process_data["carrier_in"] in carriers && process_data["carrier_out"] in carriers
            processes[process_name] = Dict(
                "carrier_in" => process_data["carrier_in"],
                "carrier_out" => process_data["carrier_out"],
            )
        else
            error("Invalid carrier in process: $(process_data["carrier_in"]) or $(process_data["carrier_out"])")
        end
    end
    return processes
end

function parse_parameters(data::Dict, input::Dict, base_path::AbstractString)::Dict
    params = Dict()
    params["defaults"] = Dict()
    for (param_name, param_data) in data["parameters"]
        if "default" in keys(param_data)
            params["defaults"][param_name] = param_data["default"]
        end

        if !("type" in keys(param_data)) || !("sets" in keys(param_data))
            error("All parameters must have a 'type' and 'sets' field.")
        end

        if param_data["sets"] == ["T"] || param_data["sets"] == ["P","Y","T"]
            error("No parameter is allowed to only have 'T' or '[P,Y,T]' as its set, but found: '$(param_name)'")
        end

        if param_data["sets"] == [] # check if the type is a vector
            params[param_name] = parse(param_data["value"], type_dict[param_data["type"]])
        elseif param_data["sets"] == ["Y"]
            params[param_name] = parse_year_dependent(param_data["value"], type_dict[param_data["type"]])
        elseif "value" in keys(param_data)
            error("Parameter '$param_name' with sets '$(param_data["sets"])' cannot have a 'value' field.")
        else
            params[param_name] = Dict()
        end
    end

    for (process, process_data) in input["processes"]
        for (param_name, param_value) in process_data["parameters"]
            type = type_dict[data["parameters"][param_name]["type"]]
            sets = data["parameters"][param_name]["sets"]
            if sets == ["P"]
                params[param_name][process] = parse(param_value, type)
            elseif sets == ["P", "T"]
                params[param_name][process] = get_time_dependent(param_value, input["timesteps"], type, base_path)
            elseif sets == ["P", "Y"]
                params[param_name][process] = get_year_dependent(param_value, input["years"], type)
            end
        end
    end
end

function get_time_dependent(param::Union{Number,AbstractString}, timesteps::Vector{Int}, type::Type, base_path)
    """
    Parse a time-dependent parameter string.
    """
    if isa(param, Number)
        return Dict(t => parse(type, param) for t in timesteps)
    elseif isa(param, AbstractString)
        values = parse_data_file(param, base_path, type)
        return Dict(t => values[t] for t in timesteps)
    end
end

function get_year_dependent(param::Union{Number,Vector}, years::Vector{Int}, type::Type)
    """
    Parse a year-dependent parameter string.
    """
    if isa(param, Number)
        return Dict(y => parse(type, param) for y in years)
    elseif isa(param, Vector)
        return linear_interpolation(param, years, type) 
    else
        error("Invalid parameter type. Expected a number or a vector.")
    end
end

function linear_interpolation(f::Vector{Dict{String,Float64}}, xq::Vector{Int}, type::Type)
    """
    Perform manual linear interpolation for a given set of x and y values.

    Parameters
    ----------
    x  : Vector{Int}       -> Known x-values (years)
    y  : Vector{Float64}   -> Known y-values (corresponding values)
    xq : Vector{Int}       -> Query x-values (years to interpolate)

    Returns
    -------
    Vector{Float64} -> Interpolated values for xq
    """
    x = Vector{Int}()
    y = Vector{type}()

    for point in f
        push!(x, point["x"])
        push!(y, point["y"])
    end

    if length(x) < 2
        error("At least two points are required for linear interpolation.")
    end

    if diff(x) .> 0
        error("x values must be in increasing order.")
    end

    n = length(x)
    interp_vals = Vector{type}()

    for x_i in xq
        # Extrapolate if x_i is out of bounds
        if x_i <= x[1]
            push!(interp_vals, y[1])  # Left boundary extrapolation
        elseif x_i >= x[end]
            push!(interp_vals, y[end])  # Right boundary extrapolation
        else
            # Find the two surrounding points
            for j in 1:n-1
                if x[j] <= x_i <= x[j+1]
                    # Linear interpolation formula
                    y_interp = y[j] + (y[j+1] - y[j]) * (x_i - x[j]) / (x[j+1] - x[j])
                    push!(interp_vals, y_interp)
                    break
                end
            end
        end
    end

    return interp_vals
end

end