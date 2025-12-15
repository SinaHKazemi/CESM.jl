module Model

using JuMP, HiGHS, Gurobi

using ..Variables
using ..Components

export get_parameter, build_model, optimize_model, get_output

function get_parameter(input, param_name, keys)
    if ! (keys isa AbstractArray || keys isa Tuple)
        keys = (keys,)
    end
    current = input.parameters[param_name]
    for key in keys
        if current isa AbstractDict && haskey(current, key)
            current = current[key]
        elseif haskey(input.parameters["defaults"], param_name)
            return input.parameters["defaults"][param_name]
        else
            return nothing
        end
    end
    return current
end



function run_optimization(input::Input)
    model,vars,constraints = build_model(input)
    # set_attribute(model, "Method", 1)
    optimize_model(model)    
    output = get_output(input, vars)
    return output
end


function build_model(input::Input, model::Union{JuMP.Model,Nothing}=nothing)
    if model === nothing
        # Gurobi
        model = JuMP.Model(Gurobi.Optimizer)
        # set_attribute(model, "Crossover", 0)
        set_attribute(model, "Method", 2)

        # HiGHS
        # model = JuMP.Model(HiGHS.Optimizer)

        # cuOpt
        # model = JuMP.Model(cuOpt.Optimizer)
    end
    vars = add_vars!(model, input)
    constraints = add_constraints!(model, vars, input)
    set_obj!(model, vars)
    return (model,vars,constraints)
end

function optimize_model(model::JuMP.Model)
    optimize!(model)
end

function get_iis_model(model)
    # needs to be completed, it is just a draft
    write_to_file(model, "model.mps")
    grb_model = model.moi_backend.optimizer.model.inner
    compute_conflict!(model)
    list_of_conflicting_constraints = ConstraintRef[]
    for (F, S) in list_of_constraint_types(model)
        for con in all_constraints(model, F, S)
            if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
                push!(list_of_conflicting_constraints, con)
            end
        end
    end
    for x in list_of_conflicting_constraints
        println(x)
    end
    iis_model, _ = copy_conflict(model)
    print(iis_model)
    write_to_file(iis_model, "model.lp")
end


# add variables
function add_vars!(model, input)
    vars = Dict()
    for (var_name, attributes) in VARIABLES
        set_names = attributes.sets
        if length(set_names) >= 1
            sets = Vector()
            for set_name in set_names
                if set_name == "Y"
                    push!(sets, input.years)
                elseif set_name == "T"
                    push!(sets, input.timesteps)
                elseif set_name == "P"
                    push!(sets, input.processes)
                elseif set_name == "C"
                    push!(sets, input.carriers)
                else
                    throw(InvalidParameterError("unrecognized set: $set_name , should be Y, T, P, C"))
                end
            end
            if length(sets) > 1
                vars[var_name] = Dict(
                    index_tuple => @variable(model, base_name= string(var_name) * "_" * join(index_tuple, "_"), lower_bound=0) for index_tuple in Iterators.product(sets...)
                )
            else
                vars[var_name] = Dict(
                    index => @variable(model, base_name= string(var_name) * "_" * string(index), lower_bound=0) for index in sets[1]
                )
            end
        elseif length(set_names) == 0
            vars[var_name] = @variable(model, base_name= string(var_name), lower_bound=0)
        else
            throw(InvalidParameterError("unrecognized set: $set_names , should be Y, T, P, C"))
        end
    end
    return vars
end

function  add_constraints!(model, vars, input::Input)::Dict
    # helper function
    function discount_factor(y::Year)::Float64
        return (1 + input.parameters["discount_rate"])^(Int(input.years[1]) - Int(y))
    end


    function year_gap(y::Year)::Int
        index = findfirst(==(y), years)
        if index == length(input.years)
            return 1
        else
            return years[index+1] - years[index]
        end
    end

    function get_param(param_name, keys)
        return get_parameter(input, param_name, keys)
    end

    function has_param(param_name, keys)
        return get_param(param_name, keys) !== nothing
    end

    # define alias for readability
    years = input.years
    timesteps = input.timesteps
    carriers = input.carriers
    processes = input.processes
    params = input.parameters

    # add constraints
    constrs = Dict()
    
    # Costs
    
    constrs["totex"] = @constraint(model, vars["total_cost"] == vars["capital_cost"] + vars["operational_cost"], base_name="totex")
    
    constrs["capex"] = @constraint(
        model,
        vars["capital_cost"] == sum(
            discount_factor(y) * sum(vars["new_capacity"][p,y] * get_param("capital_cost_power", (p,y)) for p in processes)
            for y in years
        ) - vars["total_residual_value"],
        base_name = "capex"
    )

    constrs["opex"] = @constraint(
        model,
        vars["operational_cost"] == sum( year_gap(y) * discount_factor(y) *
            (vars["annual_emission"][y] * get_param("co2_price",y) +
                sum(
                    vars["active_capacity"][p, y] * get_param("operational_cost_power",(p,y)) +
                    vars["total_energy_out"][p, y] * get_param("operational_cost_energy",(p,y))
                    for p in processes
                )
            ) 
            for y in years
        ),
        base_name = "opex"
    )


    constrs["residual_value"] = Dict()
    begin
        for p in processes
            for y in years
                if (years[end] - y + 1) < get_param("lifetime", p)
                    constrs["residual_value"][p,y] =
                    @constraint(
                        model,
                        vars["residual_value"][p,y] == vars["new_capacity"][p,y]* get_param("capital_cost_power",(p,y)) *(1-(years[end]-y+1)/get_param("lifetime", p)) * discount_factor(y),
                        base_name="salvage_$(p)_$(y)"
                    )
                end
            end
        end
    end

    constrs["total_residual_value"] = @constraint(
        model,
        vars["total_residual_value"] == sum(
            vars["residual_value"][p, y] for p in processes for y in years
            if (years[end] - y + 1) < get_param("lifetime", p)
        ),
        base_name = "total_residual_value"
    )

    # Power Balance
    
    constrs["power_balance"] = Dict()
    begin
        for c in carriers
            c == Carrier("Dummy") && continue
            for t in timesteps
                for y in years
                    constrs["power_balance"][c,y,t] = @constraint(
                        model,
                        sum(vars["power_in"][p, y, t] for p in processes if p.carrier_in == c) == 
                        sum(vars["power_out"][p, y, t] for p in processes if p.carrier_out == c),
                        base_name="power_balance_$(c)_$(y)_$(t)"
                    )
                end
            end
        end
    end

    # CO2

    constrs["co2_emission_eq"] = Dict() 
    for y in years
        constrs["co2_emission_eq"][y] = @constraint(
            model,
            vars["annual_emission"][y] == sum(get_param("specific_co2",p) * vars["total_energy_out"][p,y] for p in processes),
            base_name = "co2_emission_eq_$(y)"
        )
    end

    constrs["co2_emission_limit"] = Dict()
    for y in years
        !has_param("annual_co2_limit",y) && continue
        constrs["co2_emission_limit"][y] = @constraint(
            model,
            vars["annual_emission"][y] <= get_param("annual_co2_limit",y),
            base_name = "co2_emission_limit_$(y)"
        )
    end

    # Power Output

    constrs["efficiency"] = Dict()
    for p in processes
        get_param("is_storage",p) && continue # doesn't apply to storages
        for y in years
            for t in timesteps
                constrs["efficiency"][p,y,t] = @constraint(
                    model,
                    vars["power_out"][p,y,t] == vars["power_in"][p,y,t] * get_param("efficiency", p),
                    base_name = "efficiency_eq_$(p)_$(y)_$(t)"
                )
            end
        end
    end


    constrs["technical_availability"] = Dict()
    for p in processes
        has_param("availability_profile",p) && continue
        for y in years
            for t in timesteps
                constrs["technical_availability"][p,y,t] = @constraint(
                    model,
                    vars["power_out"][p,y,t] <= vars["active_capacity"][p,y] * get_param("technical_availability",p),
                    base_name = "technical_availability_$(p)_$(y)_$(t)"
                )
            end
        end
    end


    constrs["renewable_availability"] = Dict()
    for p in processes
        !has_param("availability_profile",p) && continue
        for y in years
            for t in timesteps
                constrs["renewable_availability"][p,y,t] = @constraint(
                    model,
                    vars["power_out"][p,y,t] <= vars["active_capacity"][p,y] * get_param("availability_profile",(p,t)),
                    base_name = "renewable_availability_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    # Power-Energy

    constrs["energy_out_time_con"] = Dict()
    for y in years
        for t in timesteps
            for p in processes
                constrs["energy_out_time_con"][p,y,t] = @constraint(
                    model,
                    vars["energy_out_time"][p,y,t] == vars["power_out"][p,y,t] * (8760 /length(input.timesteps)),
                    base_name = "energy_out_time_con_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    constrs["energy_in_time_con"] = Dict()
    for y in years
        for t in timesteps
            for p in processes
                constrs["energy_in_time_con"][p,y,t] = @constraint(
                    model,
                    vars["energy_in_time"][p,y,t] == vars["power_in"][p,y,t] * (8760 /length(input.timesteps)),
                    base_name = "energy_in_time_con_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    # Fractions

    constrs["min_carrier_generation"] = Dict()
    for p in processes
        !has_param("min_fraction_out",p) && continue
        for y in years
            for t in timesteps
                constrs["min_carrier_generation"][p,y,t] = @constraint(
                    model,
                    vars["energy_out_time"][p,y,t] >= get_param("min_fraction_out",(p,y)) * vars["net_energy_generation"][p.carrier_out,y,t],
                    base_name = "min_carrier_generation_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    constrs["max_carrier_generation"] = Dict()
    for p in processes
        !has_param("max_fraction_out",p) && continue
        for y in years
            for t in timesteps
                constrs["max_carrier_generation"][p,y,t] = @constraint(
                    model,
                    vars["energy_out_time"][p,y,t] <= get_param("max_fraction_out",(p,y)) * vars["net_energy_generation"][p.carrier_out,y,t],
                    base_name = "max_carrier_generation_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    constrs["min_carrier_consumption"] = Dict()
    for p in processes
        !has_param("min_fraction_in",p) && continue
        for y in years
            for t in timesteps
                constrs["min_carrier_consumption"][p,y,t] = @constraint(
                    model,
                    vars["energy_in_time"][p,y,t] >= get_param("min_fraction_in",(p,y)) * vars["net_energy_consumption"][p.carrier_in,y,t],
                    base_name = "min_carrier_consumption_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    constrs["max_carrier_consumption"] = Dict()
    for p in processes
        !has_param("max_fraction_in",p) && continue
        for y in years
            for t in timesteps
                constrs["max_carrier_consumption"][p,y,t] = @constraint(
                    model,
                    vars["energy_in_time"][p,y,t] <= get_param("max_fraction_in",(p,y)) * vars["net_energy_consumption"][p.carrier_in,y,t],
                    base_name = "max_carrier_consumption_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    # Capacity

    constrs["max_legacy_cap"] = Dict()
    for p in processes
        for y in years
            constrs["max_legacy_cap"][p,y] = @constraint(
                model,
                vars["legacy_capacity"][p,y] <= get_param("max_legacy_capacity", (p,y)),
                base_name = "max_legacy_cap_$(p)_$(y)"
            )
        end
    end

    constrs["min_legacy_cap"] = Dict()
    for p in processes
        !has_param("min_legacy_capacity", p) && continue
        for y in years
            !has_param("min_legacy_capacity", (p,y)) && continue
            constrs["min_legacy_cap"][p,y] = @constraint(
                model,
                vars["legacy_capacity"][p,y] >= get_param("min_legacy_capacity", (p,y)),
                base_name = "min_legacy_cap_$(p)_$(y)"
            )
        end
    end

    constrs["active_capacity"] = Dict() 
    for p in processes
        for y in years
            constrs["active_capacity"][p,y] = @constraint(
                model,
                vars["active_capacity"][p,y] == vars["legacy_capacity"][p,y] + sum(
                    vars["new_capacity"][p,yy] 
                    for yy in years 
                    if Int(yy) >= (Int(y)-get_param("lifetime",p)+1) && Int(yy) <=Int(y)
                ),
                base_name = "active_capacity_$(p)_$(y)"
            )
        end
    end

    constrs["max_active_capacity"] = Dict()
    for p in processes
        !has_param("max_capacity",p) && continue
        for y in years
            !has_param("max_capacity",(p,y)) && continue
            constrs["max_active_capacity"][p,y] = @constraint(
                model,
                vars["active_capacity"][p,y] <= get_param("max_capacity",(p,y)),
                base_name = "max_active_capacity$(p)_$(y)"
            )
        end
    end

    constrs["min_active_capacity"] = Dict()
    for p in processes
        has_param("min_capacity",p) && continue
        for y in years
            !has_param("min_capacity",(p,y)) && continue
            constrs["min_active_capacity"][p,y] = @constraint(
                model,
                vars["active_capacity"][p,y] >= get_param("min_capacity",(p,y)),
                base_name = "min_active_capacity$(p)_$(y)"
            )
        end
    end

    # Auxiliary Linking Variables

    constrs["energy_out"] = Dict() 
    for p in processes
        for y in years
            constrs["energy_out"][p,y] = @constraint(
                model,
                vars["total_energy_out"][p,y] == sum(vars["energy_out_time"][p,y,t] for t in timesteps),
                base_name = "energy_out_$(p)_$(y)"
            )
        end
    end
    
    constrs["energy_in"] = Dict()
    for p in processes
        for y in years
            constrs["energy_in"][p,y] = @constraint(
                model,
                vars["total_energy_in"][p,y] == sum(vars["energy_in_time"][p,y,t] for t in timesteps),
                base_name = "energy_in_$(p)_$(y)"
            )
        end
    end

    constrs["net_generation"] = Dict()
    for c in carriers
        for y in years
            for t in timesteps
                constrs["net_generation"][c,y,t] = @constraint(
                    model,
                    vars["net_energy_generation"][c,y,t] == sum(vars["energy_out_time"][p,y,t] for p in processes if p.carrier_out == c),
                    base_name = "net_generation_$(c)_$(y)_$(t)"
                )
            end
        end
    end

    constrs["net_consumption"] = Dict()
    for c in carriers
        for y in years
            for t in timesteps
                constrs["net_consumption"][c,y,t] = @constraint(
                    model,
                    vars["net_energy_consumption"][c,y,t] == sum(vars["energy_in_time"][p,y,t] for p in processes if p.carrier_in == c),
                    base_name = "net_consumption_$(c)_$(y)_$(t)"
                )
            end
        end
    end

    # Generation 

    constrs["max_energy_out"] = Dict()
    for p in processes
        !has_param("max_energy_out",p) && continue
        for y in years
            constrs["max_energy_out"][p,y] = @constraint(
                model,
                vars["total_energy_out"][p, y] <= get_param("max_energy_out",(p,y)),
                base_name = "max_energy_out_$(p)_$(y)"
            )
        end
    end

    constrs["min_energy_out"] = Dict()
    for p in processes
        !has_param("min_energy_out",p) && continue
        for y in years
            constrs["min_energy_out"][p,y] = @constraint(
                model,
                vars["total_energy_out"][p,y] >= get_param("min_energy_out",(p,y)),
                base_name = "min_energy_out_$(p)_$(y)"
            )
        end
    end

    constrs["load_shape"] = Dict()
    for p in processes
        !has_param("output_profile",p) && continue
        for y in years
            for t in timesteps
                constrs["load_shape"][p,y,t] = @constraint(
                    model,
                    vars["energy_out_time"][p,y,t] >= get_param("output_profile",(p,t)) * vars["total_energy_out"][p,y],
                    base_name = "load_shape_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    # Storage
    constrs["c_rate_relation"] = Dict()
    for p in processes
        !(get_param("is_storage", p)) && continue
        for y in years
            constrs["c_rate_relation"][p,y] = @constraint(
                model,
                vars["max_storage_level"][p,y] == vars["active_capacity"][p,y] / params["c_rate"][p],
                base_name = "c_rate_relation_$(p)_$(y)"
            )
        end
    end

    constrs["storage_energy_limit"] = Dict()
    for p in processes
        !(get_param("is_storage", p)) && continue
        for y in years
            for t in timesteps
                constrs["storage_energy_limit"][p,y,t] = @constraint(
                    model,
                    vars["storage_level"][p,y,t] <= vars["max_storage_level"][p,y],
                    base_name = "storage_energy_limit_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    constrs["charge_power_limit"] = Dict()
    for p in processes
        !(get_param("is_storage", p)) && continue
        for y in years
            for t in timesteps
                constrs["charge_power_limit"][p,y,t] = @constraint(
                    model,
                    vars["power_in"][p,y,t] <= vars["active_capacity"][p,y],
                    base_name = "charge_power_limit_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    constrs["storage_energy_balance"] = Dict()
    for p in processes
        !(get_param("is_storage", p)) && continue
        for y in years
            for (idx,t) in enumerate(timesteps)
                prev_t = timesteps[idx == 1 ? end : idx - 1]
                constrs["storage_energy_balance"][p,y,t] = @constraint(
                    model,
                    vars["storage_level"][p,y,t] == vars["storage_level"][p,y,prev_t]
                    + vars["power_in"][p,y,t] * params["dt"] * get_param("charge_efficiency",p)
                    - vars["power_out"][p,y,t] * params["dt"] / get_param("efficiency",p),
                    base_name = "storage_energy_balance_$(p)_$(y)_$(t)"
                )
            end
        end
    end

    return constrs
end

function set_obj!(model, vars)
    @objective(model, Min, vars["total_cost"])
end

function get_output(input::Input, vars)::Output
    output = Output()
    for (var_name, attributes) in VARIABLES
        set_names = attributes.sets
        if length(set_names) > 0
            output[var_name] = Dict()
            sets = Vector()
            for set_name in set_names
                if set_name == "Y"
                    push!(sets, input.years)
                elseif set_name == "T"
                    push!(sets, input.timesteps)
                elseif set_name == "P"
                    push!(sets, input.processes)
                elseif set_name == "C"
                    push!(sets, input.carriers)
                else
                    throw(InvalidParameterError("unrecognized set: $set_name , should be Y, T, P, C"))
                end
            end
            if length(sets) > 1
                for index_tuple in Iterators.product(sets...)
                    var_value = value(vars[var_name][index_tuple])
                    if var_value != 0
                        output[var_name][index_tuple...] = var_value
                    end
                end
            else
                for index in sets[1]
                    var_value = value(vars[var_name][index])
                    if var_value != 0
                        output[var_name][index] = var_value
                    end
                end
            end
        elseif length(set_names) == 0
            output[var_name] = value(vars[var_name])
        end
    end
    return output
end

end