module Parse

using JSON

export parse

struct TemporalSequenceError <: Exception
    msg::String
end

struct InvalidParameterError <: Exception
    msg::String
end

type_dict = Dict(
    "Float" => Float64,
    "Integer" => Int,
    "Boolean" => Bool,
    "String" => String,
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
    input["units"] = get_units(data["units"])
    input["tss"] = parse_tss(data["tss"], base_path)
    input["years"] = parse_years(data["Units"], base_path)
    input["carriers"] = parse_carriers(data["carriers"])
    input["processes"] = parse_processes(data["processes"], input["carriers"])
    input["parameters"] = get_parameters(data["parameters"], data["processes"], data["carriers"], input["years"], input["tss"], input["units"], base_path)
    return input
end

function get_units(data::Dict)::Dict
    for (unit_name, unit_data) in data
        if keys(unit_data) != Set(("input", "output", "scale"))
            throw(InvalidParameterError("each unit must have 'input', 'output', and 'scale' fields but found: '$unit_name'"))
        end

        if !(unit_data["input"] isa String && unit_data["output"] isa String && unit_data["scale"] isa Real)
            throw(InvalidParameterError("input and output fields must be String and the scale must be Real but found: '$unit_name'"))
        end

        unit_data["scale"] = convert(Float64, unit_data["scale"])
    end
    return data
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

function get_vector_or_file(x, ::Type{T}, base_path::AbstractString) where {T}
    if isa(x, Vector{T})
        return x
    elseif isa(x, AbstractString)
        return parse_data_file(x, base_path, T)
    else
        error("Input must be either Vector{$T} or a file path string.")
    end
end

function validate_temporal_sequence(values::Vector{Int})
    if ! (length(values) == length(unique(values)))
        throw(TemporalSequenceError("Duplicate values found in the vector"))
    elseif ! all(values .> 0)
        throw(TemporalSequenceError("Negative values found in the vector"))
    elseif ! all(diff(values) .> 0)
        throw(TemporalSequenceError("Non-increasing values found in the vector"))
    end
end

function parse_tss(tss_data::Union{Vector,AbstractString}, base_path::AbstractString)::Vector{Int}
    tss = get_vector_or_file(tss_data, Int, base_path)
    validate_temporal_sequence(tss)
    return tss
end

function parse_years(years_data::Union{Vector,AbstractString}, base_path::AbstractString)::Vector{Int}
    years = get_vector_or_file(years_data, Int, base_path)
    validate_temporal_sequence(years)
    return years
end

function parse_carriers(data::Dict)::Set{String}
    return(Set{String}(keys(data)))
end

function parse_processes(data::Dict, carriers::Set{String})::Dict{String, Dict{String, String}}
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

function get_time_dependent(param::Union{Number,AbstractString}, tss::Vector{Int}, type::Type, base_path) :: Dict{Int, Number}
    """
    get a time-dependent parameter that is either a number or a data file path
    """
    if isa(param, Number)
        return Dict(t => convert(type, param) for t in tss)
    elseif isa(param, AbstractString)
        values = parse_data_file(param, base_path, type)
        return Dict(t => values[t] for t in tss)
    end
end

function linear_interpolation(f::Vector{<:Dict{String,<:Number}}, xq::Vector{<:Number}, type::Type)
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
        throw(InvalidParameterError("At least two points are required for linear interpolation."))
    end

    if any(diff(x) .<= 0)
        throw(InvalidParameterError("x values must be in increasing order."))
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

function get_year_dependent(param::Union{Number,Vector}, years::Vector{Int}, type::Type)
    """
    Parse a year-dependent parameter string.
    """
    if isa(param, Number)
        return Dict(y => convert(type, param) for y in years)
    elseif isa(param, Vector)
        return Dict(zip(years, linear_interpolation(param, years, type)))
    else
        error("Invalid parameter type. Expected a number or a vector.")
    end
end

function validate_parameters(parameters::Dict)
    for (param_name, param_data) in parameters
        if !(issubset(keys(param_data), ["default", "type", "sets", "value", "quantity", "comment"]))
            throw(InvalidParameterError("Invalid parameter: $(param_name). there is an unkown field: $(keys(param_data))"))
        end

        if !(issubset(Set(["type","sets"]), keys(param_data)))
            throw(InvalidParameterError("All parameters must have a 'type' and 'sets' field."))
        end

        # check if the type is valid
        if !(param_data["type"] in keys(type_dict))
            throw(InvalidParameterError("allowable types are: '$(keys(type_dict))', but found: '$(param_name)' with type: '$(param_data["type"])'"))
        end

        type = type_dict[param_data["type"]]
        sets = Set(param_data["sets"])

        if ! issubset(sets,Set(["P","Y","T","C"]))
            throw(InvalidParameterError("All parameters sets must be a subset of [P,Y,T,C], but found: '$(param_name)' with sets: '$(param_data["sets"])'"))
        end

        allowable_sets = Set([Set(), Set(["Y"]), Set(["P"]), Set(["P","Y"]), Set(["P","T"]), Set(["C"])])
        if ! (sets in allowable_sets)
            throw(InvalidParameterError("All parameters sets must be one of the following: '$(allowable_sets)', but found: '$(param_name)' with sets: '$(param_data["sets"])'"))
        end
    end
end

function scale_dict_values(dict::Dict, scale)
    return Dict(k => v * scale for (k, v) in dict)
end

function get_independent_parameters(parameters::Dict, years::Vector{Int}, units::Dict)::Dict
    """
    Get parameters independent of processes and carriers
    """
    params = Dict()
    params["defaults"] = Dict()
    
    for (param_name, param_data) in parameters
        type = type_dict[param_data["type"]]
        sets = Set(param_data["sets"])
        if "quantity" in keys(param_data)
            scale = units[param_data["quantity"]]["scale"]
        else
            scale = nothing
        end
        # read default value
        if "default" in keys(param_data)
            temp = convert(type, param_data["default"])
            if scale !== nothing
                params["defaults"][param_name] =  temp * scale
            else
                params["defaults"][param_name] = temp
            end
        end

        # The parameters that are not process or carrier dependent
        if sets == Set([]) # check if the type is a vector
            temp = convert(type, param_data["value"])
            params[param_name] = (scale !== nothing ? scale * temp : temp)
        elseif sets == Set(["Y"])
            temp = get_year_dependent(param_data["value"], years, type)
            if scale !== nothing
                params[param_name] = scale_dict_values(temp, scale)
            else
                params[param_name] = temp
            end
        elseif "value" in keys(param_data)
            throw(InvalidParameterError("Parameter '$param_name' with sets '$(sets)' cannot have a 'value' field."))
        end
    end
    
    return params
end


function get_dependent_parameters(parameters::Dict, processes::Dict, carriers::Dict, years::Vector{Int}, tss::Vector{Int}, units::Dict,  base_path::AbstractString)::Dict
    """
    Parse a parameter dictionary.
    Parameters
    ----------
    parameters : Dict
    A dictionary containing parameter information.
    on.
    processes : Dict
    processes dictionary from raw input.
    carriers : Dict
    carriers dictionary from raw input.
    years : Vector{Int}
    vector of years from parsed input.
    tss : Vector{Int}
    tss vector from parsed input.
    """
    params = Dict()

    for (param_name, param_data) in parameters
        sets = Set(param_data["sets"])
        if ! (sets in Set((Set([]), Set(["Y"]))))
            params[param_name] = Dict()
        end
    end

    for (process, process_data) in processes
        if !("parameters" in keys(process_data))
            throw(InvalidParameterError("All processes must have a 'parameters' field but found: '$(process)'"))
        end
        for (param_name, param_value) in process_data["parameters"]
            if ! (param_name in keys(parameters))
                throw(InvalidParameterError("Parameter '$param_name' not found in parameters in process: '$(process)'"))
            end
            type = type_dict[parameters[param_name]["type"]]
            sets = parameters[param_name]["sets"]
            if "quantity" in keys(parameters[param_name])
                scale = units[parameters[param_name]["quantity"]]["scale"]
            else
                scale = nothing
            end
            if sets == ["P"]
                temp = convert(type, param_value) 
                params[param_name][process] = (scale !== nothing  ? scale * temp : temp)
            elseif sets == ["P", "T"]
                temp = get_time_dependent(param_value, tss, type, base_path)
                params[param_name][process] = (scale !== nothing ? scale_dict_values(temp, scale) : temp )
            elseif sets == ["P", "Y"]
                temp = get_year_dependent(param_value, years, type)
                params[param_name][process] = (scale !== nothing ? scale_dict_values(temp, scale) : temp )
            end
        end
    end

    for (carrier, carrier_data) in carriers
        for (param_name, param_value) in carrier_data["parameters"]
            if ! (param_name in keys(parameters))
                throw(InvalidParameterError("Parameter '$param_name' not found in parameters in carrier: '$(carrier)'."))
            end
            type = type_dict[parameters[param_name]["type"]]
            sets = parameters[param_name]["sets"]
            if sets == ["C"]
                params[param_name][carrier] = convert(type,param_value)
            end
        end
    end

    return params
end

function get_parameters(parameters::Dict, processes::Dict, carriers::Dict, years::Vector{Int}, tss::Vector{Int}, units::Dict, base_path::AbstractString)::Dict
    """
    Parse a parameter dictionary.
    """
    validate_parameters(parameters)
    independent_parameters = get_independent_parameters(parameters, years, units)
    dependent_parameters = get_dependent_parameters(parameters, processes, carriers, years, tss, units, base_path)
    return merge(independent_parameters, dependent_parameters)
end

end