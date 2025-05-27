module Parse
using XLSX
using DataFrames

export parse

struct ParseError <: Exception
    msg::String
end

type_dict = Dict(
    "Float" => Float64,
    "Integer" => Int,
    "Boolean" => Bool
)


function parse(file_path, scenario)
    XLSX.openxlsx(file_path) do workbook
        input = Dict()
        input[:sets] = Dict()
        input[:plot] = Dict()
        
        unit_output = parse_units(workbook["Units"])
        input[:units] = unit_output
        scenario_output = parse_scenario(workbook["Scenario"], scenario)
        input[:sets][:Y] = scenario_output.years
        co_output = parse_commodity(workbook["Commodity"])
        input[:sets][:CO] = co_output.co
        input[:plot][:CO] = co_output.plot
        tss_output = parse_tss(workbook["TimeSeriesSelection"], scenario_output.tss)
        input[:sets][:T] = tss_output.tss
        cp_output = parse_cp(workbook, co_output.co, scenario_output.years, tss_output.tss, unit_output)
        input[:sets][:CP] = cp_output.cp
        input[:plot][:CP] = cp_output.plot
        input[:params] = merge(cp_output.params, scenario_output.params)
        input[:params][:dt] = tss_output.dt
        input[:defaults] = merge(cp_output.defaults, scenario_output.defaults)
        return input
    end
    
end


function parse_units(sheet::XLSX.Worksheet)::Dict{Symbol,Dict{Symbol,Union{String,Real}}}
    df = DataFrame(XLSX.gettable(sheet))
    units_dict = Dict{Symbol,Dict}()
    for row in eachrow(df)
        units_dict[Symbol(row[:quantity])] = Dict(
            :input => row[:input],
            :scale => Float64(row[:scale_factor]),
            :output => row[:output]
        )
    end
    return units_dict
end


function parse_scenario(sheet::XLSX.Worksheet, name::String)
    df = DataFrame(XLSX.gettable(sheet))
    params = Dict{Symbol,Any}()
    defaults = Dict{Symbol,Any}()
    years = Vector{Int}()
    # Filter the data and keep only the scenario you want
    filtered_df = df[df.name .== name, :]
    if nrow(filtered_df) == 0
        throw(ParseError("There is no scenario with name: $name."))
    elseif nrow(filtered_df) > 1
        throw(ParseError("There are more than one scenario named $name. The name of the scenarios must be unique."))
    end
    scenario_row = first(filtered_df)
    default_row = first(df[df.name .== "Default", :])
    type_row = first(df[df.name .== "Type", :])
    sets_row = first(df[df.name .== "Sets", :])

    years = collect(range(Int(scenario_row[:from_year]), stop= Int(scenario_row[:until_year]), step=Int(scenario_row[:year_step])))
    tss = scenario_row[:tss]

    for key in keys(scenario_row)
        if key in (:name, :from_year, :until_year, :year_step, :tss, :disabled_cp)
            continue
        end
        if !ismissing(default_row[key])
            defaults[key] = tryparse(type_dict[type_row[key]], string(default_row[key]))
        end
        if !ismissing(scenario_row[key])
            if ismissing(sets_row[key])
                params[key] = tryparse(type_dict[type_row[key]], string(scenario_row[key]))
            elseif sets_row[key] == "Y"
                params[key] = Dict(zip(years,parse_pw(string(scenario_row[key]), years, Int)))
            else
                throw(ParseError("??"))
            end
        end
    end
    return (tss=tss, params=params, defaults=defaults, years=years)
end

function parse_commodity(sheet::XLSX.Worksheet)::NamedTuple{(:co, :plot), Tuple{Vector{Symbol}, Dict{Symbol,NamedTuple}}}
    # reads co names and generates a vector of these names
    # reads the color and order for each co and generates a dictionary with co name as key and namedtuple of color and order as values
    df = DataFrame(XLSX.gettable(sheet))
    co = Vector{Symbol}() # vector of commodity names
    plot = Dict{Symbol,NamedTuple{(:color,:order),Tuple{Union{Nothing,String},Union{Nothing,Int}}}}() # dictionary with commodi as key and namedtuple of order and color as value
    for row in eachrow(df)
        co_name = Symbol(row[:name])
        push!(co,co_name)
        order = nothing
        color= nothing
        if !ismissing(row[:order])
            order = Int(row[:order])
        end
        if !ismissing(row[:color])
            color = row[:color]
        end
        plot[co_name] = (color=color,order=order)
    end
    return (co=co, plot=plot)
end

function parse_tss(sheet::XLSX.Worksheet, name::String)::NamedTuple{(:dt, :tss), Tuple{Int, Vector{Int}}}
    df = DataFrame(XLSX.gettable(sheet))
    column = df[!, Symbol(name)]
    dt = Int(column[2])
    if any(ismissing, column[3:end])
        end_index = findfirst(ismissing, column[3:end])
    else
        end_index = length(column)
    end
    tss = map(Int, column[3:end_index])
    return (dt=dt, tss=tss)
end

function parse_ts(sheet::XLSX.Worksheet, name::String, tss::Vector{Int}, type::Type)::Vector{Float64}
    df = DataFrame(XLSX.gettable(sheet))
    column = df[!, Symbol(name)]
    if any(ismissing, column[2:end])
        end_index = findfirst(ismissing, column[2:end])
    else
        end_index = length(column)
    end
    ts = map(type, column[2:end_index])
    ts = ts[tss]
    return ts
end

function parse_cp(book, co::Vector{Symbol}, years::Vector{Int}, tss::Vector{Int}, units_output)
    df = DataFrame(XLSX.gettable(book["ConversionProcess"]))
    cp_dict=Dict{Symbol,NamedTuple{(:cin,:cout),Tuple{Symbol,Symbol}}}()
    plot_dict=Dict{Symbol,NamedTuple{(:color,:order),Tuple{Union{Nothing,String},Union{Nothing,Int}}}}()
    params = Dict{Symbol,Any}()
    defaults = Dict{Symbol,Any}()
    default_row = df[findfirst(x -> x == 1, df.rows .== "Default"), :]
    type_row = df[findfirst(x -> x == 1, df.rows .== "Type"), :]
    sets_row = df[findfirst(x -> x == 1, df.rows .== "Sets"), :]
    dimension_row = df[findfirst(x -> x == 1, df.rows .== "Dimension"), :]
    dimension_dict = Dict{Symbol,Float64}()
    for param in keys(default_row)
        param in (:name, :cin, :cout, :color, :order, :rows, :description) && continue
        defaults[param] = tryparse(type_dict[type_row[param]], string(default_row[param]))
        params[param] = Dict{Symbol,Any}()
        if !ismissing(dimension_row[param])
            dimension_dict[param] = units_output[Symbol(dimension_row[param])][:scale]
        end
    end
    for row in eachrow(df)
        ismissing(row[:name]) && continue
        cp_name = Symbol(row[:name])
        cp_name in keys(cp_dict) && throw(ParseError("CP $cp_name already exists. cp name must be unique."))
        !(Symbol(row[:cin]) in co) && throw(ParseError("commodity $(row[:cin]) doesn't exist in the list of commodities "))
        !(Symbol(row[:cout]) in co) && throw(ParseError("commodity $(row[:cout]) doesn't exist in the list of commodities "))
        cp_dict[cp_name] = (cin=Symbol(row[:cin]), cout=Symbol(row[:cout]))
        cp_color = ismissing(row[:color]) ? nothing : row[:color]
        cp_order = ismissing(row[:order]) ? nothing : row[:order]
        plot_dict[cp_name] = (color=cp_color, order=cp_order)
        for param in keys(row)
            scale = get(dimension_dict, param, 1)
            param in (:name, :cin, :cout, :color, :order, :rows, :description) && continue
            ismissing(row[param]) && continue
            if ismissing(sets_row[param])
                params[param][cp_name] = Base.parse(type_dict[type_row[param]], string(row[param])) * scale
            elseif sets_row[param] == "Y"
                params[param][cp_name] = Dict(zip(years, parse_pw(string(row[param]), years, type_dict[type_row[param]]) .* scale))
                # params[param][cp_name] = 1 
            elseif sets_row[param] == "T"
                ts = parse_ts(book["TimeSeries"], row[param], tss, type_dict[type_row[param]])
                if param == :output_profile
                    ts = ts ./ sum(ts)
                    # ts[end] -= sum(ts)-1
                end
                params[param][cp_name] = Dict(zip(tss, ts))
            else
                throw(ParseError("$(sets_row[param]) type is not a valid type."))
            end
        end
        
    end
    return (cp=cp_dict, plot=plot_dict, params=params, defaults=defaults)
end


function parse_pw(param::String, years::Vector{Int}, type::Type)
    """
    Get interpolated values for a given vector of years based on year-value pairs.

    If `param` is a single numeric value, return a vector of that value with the same length as `years`.
    Otherwise, extract year-value pairs and perform linear interpolation.

    Parameters
    ----------
    param : String
        String containing either:
        - A single numeric value (e.g., "5.0")
        - Year-value pairs in the format: "YYYY value ; YYYY value ; ..."
    years : Vector{Int}
        Vector of integer years for which interpolation values should be calculated.

    Returns
    -------
    Vector{type}
        Vector of interpolated values corresponding to input years.
    """

    param = strip(param)  # Remove leading/trailing spaces

    # Case 1: Single numeric value (return a constant vector)
    single_value = tryparse(Float64, param)  # Try parsing as a single number

    if single_value !== nothing
        return fill(single_value, length(years))  # Return a vector with the same value
    end

    # Case 2: Year-value pairs (parse and interpolate)
    yy, vals = Int[], Float64[]

    # Case 2: Year-value pairs inside brackets (e.g., "[2016 23.3; 2040 0]")
    m = match(r"\[(.*?)\]", param)
    if m === nothing
        error("Invalid format. Expected a single number or '[YYYY value; YYYY value; ...]'")
    end

    param = m.captures[1]  # Extract content inside brackets
    yy, vals = Int[], Float64[]

    for pair in split(param, ";")
        tokens = split(strip(pair))
        if length(tokens) != 2
            continue  # Skip malformed entries
        end

        try
            year = Base.parse(Int, tokens[1])
            val = lowercase(tokens[2]) == "nan" ? NaN : Base.parse(Float64, tokens[2])

            if !isnothing(val) && !isnan(val)
                push!(yy, year)
                push!(vals, val)
            end
        catch
            continue  # Skip invalid numerical conversions
        end
    end


    if isempty(yy)
        error("No valid year-value pairs found.")
    end

    # Create interpolation function
    if length(yy) > 1
        itp = x -> linear_interpolation(yy, vals, x)
    else
        itp = x ->  [ i == yy[1] ? vals[1] : Inf for i in x ]  # Return constant value
    end

    return itp(years)  # Interpolate and return results as a vector
end


function linear_interpolation(x::Vector{Int}, y::Vector{Float64}, xq::Vector{Int})
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

    n = length(x)
    interp_vals = Float64[]

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


# parse("data/DEModel.xlsx")
# println(parse("data/DEModel.xlsx"))
    

end




