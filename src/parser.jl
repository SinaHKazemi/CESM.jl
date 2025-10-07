module Parser

using JSON
using ..Components

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


"""
    strip_comments!(data)

Recursively removes all keys starting with `"_comment"` from a dictionary `data`.
Supports nested dictionaries and vectors containing dictionaries.

This function **modifies the input in-place**.

# Arguments
- `data`: A `Dict` or `Vector` (possibly nested) containing dictionaries.

# Returns
- The modified `data` with comment keys removed.
"""
function strip_comments!(data)
    if isa(data, Dict)
        # Collect keys to remove first to avoid modifying dict during iteration
        keys_to_remove = [k for k in keys(data) if isa(k, AbstractString) && startswith(k, "_comment")]
        for k in keys_to_remove
            delete!(data, k)
        end
        # Recursively process remaining values
        for v in values(data)
            strip_comments!(v)
        end
    elseif isa(data, Vector)
        for item in data
            strip_comments!(item)
        end
    end
    return data
end

"""
    parse_input(path::AbstractString) -> Input

Reads a JSON configuration file from `path` and returns an `Input` struct.

# Arguments
- `path::AbstractString`: Path to the `config.json` file.

# Returns
- `Input`: The input struct containing all configuration data.

"""
function parse_input(path::AbstractString)::Input
    fullpath = abspath(path)  # normalize to absolute path
    base_path = dirname(fullpath)

    if !isfile(fullpath)
        error("JSON file not found: $fullpath")
    end

    data = open(fullpath, "r") do io
        JSON.parse(read(io, String))
    end

    # strip comments
    strip_comments!(data)
    
    units = get_units(data["units"])
    timesteps = parse_timesteps(data["timesteps"], base_path)
    years = parse_years(data["years"], base_path)
    carriers = parse_carriers(data["carriers"])
    processes = parse_processes(data["processes"], carriers)
    parameters = get_parameters(data["parameters"], data["processes"], data["carriers"], years, timesteps, units, base_path)
    input = Input(units,  years, timesteps, carriers, processes, parameters)
    return input
end

"""
    get_units(units::Dict) -> Dict{String, Unit}

Converts a dictionary of unit definitions into a dictionary mapping string keys
to `Unit` objects.

# Arguments
- `units::Dict`: A dictionary where keys are unit names (strings) and values
  contain unit definitions.

# Returns
- `Dict{String, Unit}`: A dictionary mapping unit names to `Unit` objects.
"""
function get_units(units::Dict)::Dict{String,Unit}
    output = Dict{String,Unit}()
    for (unit_name, unit_data) in units
        if keys(unit_data) != Set(("input", "output", "scale"))
            throw(InvalidParameterError("Each unit must have 'input', 'output', and 'scale' fields but found: '$unit_name'"))
        end

        if !(unit_data["input"] isa String && unit_data["output"] isa String && unit_data["scale"] isa Real)
            throw(InvalidParameterError("input and output fields must be String and the scale must be Real but found: '$unit_name'"))
        end

        unit_data["scale"] = convert(Float64, unit_data["scale"])
        output[unit_name] = Unit(unit_data["input"], unit_data["output"], unit_data["scale"])
    end
    return output
end

"""
    parse_data_file(path::AbstractString, base_path::AbstractString, ::Type{T}) -> Vector{T}

Reads a text file containing values of type `T` and returns them as a vector.
Supports relative paths with a base directory and skips full-line comments starting with `#`.
The values can be split using a space, tab, comma or newline.

# Arguments
- `path::AbstractString`: Path to the data file (can be relative or absolute).
- `base_path::AbstractString`: Base path used if `path` is relative.
- `T::Type`: Element type of the output vector (e.g., `Int`, `Float64`).

# Returns
- `Vector{T}`: A vector of parsed values of type `T`.
"""
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

"""
    get_vector_or_file(x::Union{Vector,AbstractString}, ::Type{T}, base_path::AbstractString) -> Vector{T}

Returns a vector of type `T` from either:

1. A vector `x` containing elements of type `T` or convertible to `T`.
2. A string `x` representing a file path containing values of type `T`.

# Behavior
- If `x` is already `Vector{T}`, it is returned as-is.
- If `x` is a `Vector` of a different type, each element is converted to `T`.
- If `x` is a string, the file at that path (relative to `base_path` if needed) is parsed using `parse_data_file`.
- Any invalid input will raise an error.

# Arguments
- `x::Union{Vector,AbstractString}`: Either a vector of values or a string path to a data file.
- `T::Type`: The type of elements in the returned vector (e.g., `Int`, `Float64`).
- `base_path::AbstractString`: Base path used if `x` is a relative file path.

# Returns
- `Vector{T}`: The resulting vector of type `T`.
"""
function get_vector_or_file(x::Union{Vector,AbstractString}, ::Type{T}, base_path::AbstractString) where {T}
    if isa(x, Vector{T})
        return x
    elseif isa(x, Vector)
        result = T[]
        for elem in x
            try
                push!(result, convert(T, elem))
            catch
                error("Element $elem is not convertable to $T.")
            end
        end
        return result
    elseif isa(x, AbstractString)
        return parse_data_file(x, base_path, T)
    else
        error("Input must be either Vector{$T} or a file path string.")
    end
end

"""
    validate_temporal_sequence(values::Vector{Int})

Validates that a vector of integer temporal values satisfies the following conditions:

1. All elements are unique.
2. All elements are positive.
3. Elements are strictly increasing (ascending order).

# Arguments
- `values::Vector{Int}`: A vector of integer temporal values.

# Throws
- `TemporalSequenceError` if any of the validation rules are violated.
"""
function validate_temporal_sequence(values::Vector{Int})
    if ! (length(values) == length(unique(values)))
        throw(TemporalSequenceError("Duplicate values found in the vector"))
    elseif ! all(values .> 0)
        throw(TemporalSequenceError("Negative values found in the vector"))
    elseif ! all(diff(values) .> 0)
        throw(TemporalSequenceError("Non-increasing values found in the vector"))
    end
end

"""
    parse_timesteps(timesteps_data::Union{Vector,AbstractString}, base_path::AbstractString) -> Vector{Time}

Parses a sequence of temporal steps and returns them as a vector of `Time` objects.

# Behavior
- If `timesteps_data` is a vector, it is used directly (elements are converted to `Int` if needed).
- If `timesteps_data` is a string, it is treated as a file path relative to `base_path` and parsed using `get_vector_or_file`.
- Validates that the resulting sequence is unique, positive, and strictly increasing using `validate_temporal_sequence`.
- Converts each timestep to a `Time` object.

# Arguments
- `timesteps_data`: A vector of integers or a file path string containing integer timesteps.
- `base_path`: Base path used if `timesteps_data` is a relative file path.

# Returns
- `Vector{Time}`: A vector of `Time` objects representing the temporal sequence.
"""
function parse_timesteps(timesteps_data::Union{Vector,AbstractString}, base_path::AbstractString)::Vector{Time}
    timesteps = get_vector_or_file(timesteps_data, Int, base_path)
    validate_temporal_sequence(timesteps)
    return [Time(t) for t in timesteps]
end

"""
    parse_years(years_data::Union{Vector,AbstractString}, base_path::AbstractString) -> Vector{Year}

Parses a sequence of years and returns them as a vector of `Year` objects.

# Behavior
- If `years_data` is a vector, it is used directly (elements are converted to `Int` if needed).
- If `years_data` is a string, it is treated as a file path relative to `base_path` and parsed using `get_vector_or_file`.
- Validates that the resulting sequence is unique, positive, and strictly increasing using `validate_temporal_sequence`.
- Converts each year to a `Year` object.

# Arguments
- `years_data`: A vector of integers or a file path string containing integer years.
- `base_path`: Base path used if `years_data` is a relative file path.

# Returns
- `Vector{Year}`: A vector of `Year` objects representing the temporal sequence.
"""
function parse_years(years_data::Union{Vector,AbstractString}, base_path::AbstractString)::Vector{Year}
    years = get_vector_or_file(years_data, Int, base_path)
    validate_temporal_sequence(years)
    return [Year(y) for y in years]
end

"""
    parse_carriers(carriers_json::Dict{String,Any}) -> Set{Carrier}

Parses a dictionary of carriers and returns a set of `Carrier` objects.

# Behavior
- The keys of the input dictionary are interpreted as carrier names.
- Each key is converted to a `Carrier` object.
- Returns a `Set{Carrier}` containing all carriers.

# Arguments
- `carriers_json::Dict{String,Any}`: A dictionary where keys are carrier names and values contain carrier properties (values are ignored here).

# Returns
- `Set{Carrier}`: A set of `Carrier` objects.
"""
function parse_carriers(carriers_json::Dict{String,Any})::Set{Carrier}
    return Set(Carrier(c) for c in keys(carriers_json))
end


function parse_processes(processes::Dict{String,Any}, carriers::Set{Carrier})::Set{Process}
    output = Set{Process}()
    for (name,process) in processes
        carrier_in = Carrier(process["carrier_in"])
        carrier_out = Carrier(process["carrier_out"])
        if (carrier_in in carriers) && (carrier_out in carriers)
            p = Process(name, carrier_in, carrier_out)
            push!(output, p)
        else
            InvalidParameterError("Invalid carrier in process $(name): $(carrier_in) or $(carrier_out)")
        end
    end
    return output
end

function get_time_dependent(param::Union{Number,AbstractString}, timesteps::Vector{Time}, type::Type, normalized::Bool, base_path) :: Dict{Time, Number}
    """
    get a time-dependent parameter that is either a number or a data file path
    """
    if isa(param, Number)
        return Dict(t => convert(type, param) for t in timesteps)
    elseif isa(param, AbstractString)
        elements = parse_data_file(param, base_path, type)
        result = Dict(t => elements[Int(t)] for t in timesteps)
        if normalized
            total = sum(values(result))
            for k in keys(result)
                result[k]/= total
            end
            total = sum(values(result))
            diff = total - 1
            for k in keys(result)
                if result[k] > diff
                    result[k] -= diff
                    break
                end
            end
        end
        return result
    end
end

function linear_interpolation(x::Vector{Int}, y::Vector{<:Number}, xq::Vector{Int}, type::Type)
    """
    Perform manual linear interpolation for a given set of x and y values.
    Ignores any value for xq out of the x range.

    Parameters
    ----------
    x  : Vector{Int}       -> Known x-values (years)
    y  : Vector{Float64}   -> Known y-values (corresponding values)
    xq : Vector{Int}       -> Query x-values (years to interpolate)

    Returns
    -------
    Vector{Float64} -> Interpolated values for xq
    """

    if length(x) < 2
        throw(InvalidParameterError("At least two points are required for linear interpolation."))
    end

    if any(diff(x) .<= 0)
        throw(InvalidParameterError("x values must be in increasing order."))
    end

    n = length(x)
    interp_vals = Vector()

    for x_i in xq
        # Ignore if x_i is out of bounds
        if x_i < x[1]
            push!(interp_vals, nothing)
        elseif x_i > x[end]
            push!(interp_vals, nothing)  # Right boundary extrapolation
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

function get_year_dependent(param::Union{Number,Vector}, years::Vector{Year}, type::Type)
    """
    Parse a year-dependent parameter string.
    """
    if isa(param, Number)
        return Dict(y => convert(type, param) for y in years)
    elseif isa(param, Vector)
        x = Vector{Int}()
        y = Vector{type}()
        for point in param
            push!(x, point["x"])
            push!(y, point["y"])
        end
        return Dict(y => v for (y, v) in zip(years, linear_interpolation(x,y, Int.(years), type)) if v !== nothing)
    else
        error("Invalid parameter type. Expected a number or a vector.")
    end
end

# Initial validation of the parameter definitions
function validate_parameters(parameters::Dict)
    for (param_name, param_data) in parameters
        if !(issubset(keys(param_data), ["default", "type", "sets", "value", "normalized", "unit"]))
            throw(InvalidParameterError("Invalid parameter: $(param_name). there is an unkown field: $(keys(param_data))"))
        end

        if !(issubset(Set(["type","sets"]), keys(param_data)))
            throw(InvalidParameterError("All parameters must have a 'type' and 'sets' field."))
        end

        # check if the type is valid
        if !(param_data["type"] in keys(type_dict))
            throw(InvalidParameterError("Allowable types are: '$(keys(type_dict))', but found: '$(param_name)' with type: '$(param_data["type"])'"))
        end

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

function get_independent_parameters(parameters::Dict, years::Vector{Year}, units::Dict{String,Unit})::Dict
    """
    Get parameters independent of processes and carriers
    """
    params = Dict()
    params["defaults"] = Dict()
    
    for (param_name, param_data) in parameters
        type = type_dict[param_data["type"]]
        sets = Set(param_data["sets"])
        if "unit" in keys(param_data)
            scale = units[param_data["unit"]].scale
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
        if sets == Set([]) 
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

function get_dependent_parameters(parameters::Dict, processes_json::Dict{String, Any}, carriers_json::Dict{String, Any}, years::Vector{Year}, timesteps::Vector{Time}, units::Dict{String,Unit},  base_path::AbstractString)::Dict
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
    timesteps : Vector{Int}
    timesteps vector from parsed input.
    """
    params = Dict()

    for (param_name, param_data) in parameters
        sets = Set(param_data["sets"])
        if ! (sets in Set((Set([]), Set(["Y"]))))
            params[param_name] = Dict()
        end
    end

    for (name,process_dict) in processes_json
        process = Process(name, Carrier(process_dict["carrier_in"]), Carrier(process_dict["carrier_out"]))
        for (param_name, param_value) in process_dict
            if param_name in ["carrier_in", "carrier_out"]
                continue
            end
            if ! (param_name in keys(parameters))
                throw(InvalidParameterError("Parameter '$param_name' not found in parameters in process: '$(process)'"))
            end
            type = type_dict[parameters[param_name]["type"]]
            sets = Set(parameters[param_name]["sets"])
            if "unit" in keys(parameters[param_name])
                scale = units[parameters[param_name]["unit"]].scale
            else
                scale = nothing
            end
            if sets == Set(["P"])
                temp = convert(type, param_value) 
                params[param_name][process] = (scale !== nothing  ? scale * temp : temp)
            elseif sets == Set(["P", "T"])
                temp = get_time_dependent(param_value, timesteps, type, parameters[param_name]["normalized"], base_path)
                params[param_name][process] = (scale !== nothing ? scale_dict_values(temp, scale) : temp )
            elseif sets == Set(["P", "Y"])
                temp = get_year_dependent(param_value, years, type)
                params[param_name][process] = (scale !== nothing ? scale_dict_values(temp, scale) : temp )
            end
        end
    end

    for (name,carrier_dict) in carriers_json
        carrier = Carrier(name)
        for (param_name, param_value) in carrier_dict
            if ! (param_name in keys(parameters))
                throw(InvalidParameterError("Parameter '$param_name' not found in parameters in carrier: '$(carrier)'."))
            end
            type = type_dict[parameters[param_name]["type"]]
            sets = Set(parameters[param_name]["sets"])
            if sets == Set(["C"])
                params[param_name][carrier] = convert(type,param_value)
            end
        end
    end

    return params
end

function get_parameters(parameters::Dict, processes_json::Dict{String, Any}, carriers_json::Dict{String, Any}, years::Vector{Year}, timesteps::Vector{Time}, units::Dict{String,Unit}, base_path::AbstractString)::Dict
    """
    Parse a parameter dictionary.
    """
    validate_parameters(parameters)
    independent_parameters = get_independent_parameters(parameters, years, units)
    dependent_parameters = get_dependent_parameters(parameters, processes_json, carriers_json, years, timesteps, units, base_path)
    return merge(independent_parameters, dependent_parameters)
end

end