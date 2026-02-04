module MGAFunctions

using JuMP
using ...CESM.Model
using ...CESM.Components

export MGA_OBJECTIVE_DEFS

# --- REGISTRY LOGIC ---

const MGA_OBJECTIVE_DEFS = Dict{String, NamedTuple{(:desc, :func), Tuple{String, Function}}}()

"""
    add_objective!(name::String, desc::String, func::Function)

Registers an MGA objective. Throws an error if the name is not unique.
"""
function add_objective!(name::String, desc::String, func::Function)
    if haskey(MGA_OBJECTIVE_DEFS, name)
        error("Critical Error: Duplicate definition for MGA objective '$name'. Objective names must be unique.")
    end
    MGA_OBJECTIVE_DEFS[name] = (desc=desc, func=func)
end

# --- OBJECTIVE DEFINITIONS ---

add_objective!(
    "total_renewable_capacity",
    "Total new renewable capacity added across all planning years.",
    function (input, source)
        ren_p = filter(p -> (t = get_parameter(input, "tags", p); t !== nothing && "renewable" in t), collect(input.processes))
        return isempty(ren_p) ? 0.0 : sum(get(source["new_capacity"], (p, y), 0.0) for p in ren_p for y in input.years)
    end
)

add_objective!(
    "total_pv_capacity",
    "Total new solar PV capacity added across all planning years.",
    function (input, source)
        pv_p = filter(p -> (t = get_parameter(input, "tags", p); t !== nothing && "solar" in t), collect(input.processes))
        return isempty(pv_p) ? 0.0 : sum(get(source["new_capacity"], (p, y), 0.0) for p in pv_p for y in input.years)
    end
)

add_objective!(
    "total_wind_capacity",
    "Total new wind capacity added across all planning years.",
    function (input, source)
        wind_p = filter(p -> (t = get_parameter(input, "tags", p); t !== nothing && "wind" in t), collect(input.processes))
        return isempty(wind_p) ? 0.0 : sum(get(source["new_capacity"], (p, y), 0.0) for p in wind_p for y in input.years)
    end
)

add_objective!(
    "total_storage_capacity",
    "Total new energy storage power capacity added across all years.",
    function (input, source)
        st_p = filter(p -> (t = get_parameter(input, "tags", p); t !== nothing && "storage" in t), collect(input.processes))
        return isempty(st_p) ? 0.0 : sum(get(source["new_capacity"], (p, y), 0.0) for p in st_p for y in input.years)
    end
)

add_objective!(
    "total_imports",
    "Total energy imported from external grids/sources over the entire horizon.",
    function (input, source)
        imp_p = filter(p -> (t = get_parameter(input, "tags", p); t !== nothing && "import" in t), collect(input.processes))
        return isempty(imp_p) ? 0.0 : sum(get(source["power_out"], (p, y, t), 0.0) for p in imp_p for y in input.years for t in input.timesteps)
    end
)

add_objective!(
    "early_emissions",
    "Sum of CO2 emissions in the first half of the horizon.",
    function (input, source)
        mid_index = max(1, div(length(input.years), 2))
        early_years = input.years[1:mid_index]
        return sum(get(source["annual_emission"], y, 0.0) for y in early_years)
    end
)

add_objective!(
    "total_capital_cost",
    "Total investment cost (CAPEX).",
    (input, source) -> source["capital_cost"]
)

add_objective!(
    "total_cost",
    "Total discounted system cost.",
    (input, source) -> source["total_cost"]
)

end
