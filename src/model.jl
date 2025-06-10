module Model

using JuMP, HiGHS, Gurobi
using Dictionary

include("variables.jl")

using .Variables
using .Components

export run_cesm


variables = Variables.variables

function run_cesm(input::Input)
    model = JuMP.Model(Gurobi.Optimizer)
    vars = add_vars!(model, input)
    add_constraints!(model, vars, input)
    set_obj!(model, vars)
    optimize!(model)

    # write_to_file(model, "model.mps")
    # grb_model = model.moi_backend.optimizer.model.inner
    # compute_conflict!(model)
    # list_of_conflicting_constraints = ConstraintRef[]
    # for (F, S) in list_of_constraint_types(model)
    #     for con in all_constraints(model, F, S)
    #         if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
    #             push!(list_of_conflicting_constraints, con)
    #         end
    #     end
    # end
    # for x in list_of_conflicting_constraints
    #     println(x)
    # end
    # iis_model, _ = copy_conflict(model)
    # print(iis_model)

    output = get_output(input, vars)
    return output
end


# add variables
function add_vars!(model, input)::Dictionary
    vars = Dictionary()
    for (var_name, attributes) in variables
        set_names = attributes.sets
        if length(set_names) >= 1
            sets = Vector()
            for set_name in set_names
                if set_name == "Y"
                    push!(sets, input["years"])
                elseif set_name == "T"
                    push!(sets, input["tss"])
                elseif set_name == "P"
                    push!(sets, keys(input["processes"]))
                elseif set_name == "C"
                    push!(sets, input["carriers"])
                else
                    throw(InvalidParameterError("unrecognized set: $set_name , should be Y, T, P, C"))
                end
            end
            vars[var_name] = Dict(
                index_tuple => @variable(model, base_name= string(var_name) * "_" * join(index_tuple, "_"), lower_bound=0) for index_tuple in Iterators.product(sets...)
            )               
        elseif length(set_names) == 0
            vars[var_name] = @variable(model, base_name= string(var_name), lower_bound=0)
        else
            throw(InvalidParameterError("unrecognized set: $set_names , should be Y, T, P, C"))
        end
    end
    return vars
end


# helper function
function discount_factor(first_year::Int, discount_rate::Float64, y::Int)::Float64
    return (1 + discount_rate^(first_year - y))
end

function year_gap(years::Vector{Int}, y::Int)::Int
    index = findfirst(==(y), years)
    if index == length(years)
        return 1
    else
        return years[index+1] - years[index]
    end
end

# function get_salvage_value(input,cp,y)::Float64
#     last_year = input[:sets][:Y][end]
#     salvage_value =  vars[:CapNew][cp,y]* input[:params][:capex_cost_power][cp,y]*(1-(last_year-y+1)/input[:params][cp])
#     return salvage_value * discount_factor(input,last_year)
# end

function  add_constraints!(model, vars, input::Input)::Dict
    # add constraints
    constrs = Dict()
    params = input["parameters"]
    defaults = input["parameters"]["defaults"]
    constrs["totex"] = @constraint(model, vars["total_cost"] == vars["capital_cost"] + vars["operational_cost"], base_name="totex")
    
    constrs["capex"] = @constraint(
        model,
        vars["capital_cost"] == sum(
            discount_factor(input["years"][1],params["discount_rate"], y) * 
            sum(vars["new_capacity"][p,y]) * (haskey(params["capital_cost_power"],p) ? params["capital_cost_power"][p][y]  : defaults["capital_cost_power"]) for p in keys(input["processes"])
            for y in input["years"]
        ) - vars["total_residual_value"],
        base_name = "capex"
    )

    constrs["opex"] = @constraint(
        model,
        vars["operational_cost"] == sum(
            (
                (
                    vars["active_capacity"][p, y] * (haskey(params["operational_cost_power"],p) ? params["operational_cost_power"][p][y] : defaults["operational_cost_power"]) +
                    vars["total_energy_out"][p, y] * (haskey(params["operational_cost_energy"],p) ? params["operational_cost_energy"][p][y] : defaults["operational_cost_energy"]) +
                    (haskey(params,"co2_price") ? params["co2_price"][y] : defaults["co2_price"]) * vars["annual_emission"][y]
                ) * year_gap(input["years"], y) * discount_factor(input["years"][1],params["discount_rate"], y)
            )
            for p in keys(input["processes"])
            for y in input["years"]
        ),
        base_name = "opex"
    )


    constrs["residual_value"] = Dict()
    begin
        last_year = input["years"][end]
        for p in keys(input["processes"])
            lifetime = get(params["lifetime"],p,defaults["lifetime"])
            for y in input["years"]
                if (last_year - y) < lifetime
                    capital_cost_power = haskey(params["capital_cost_power"],p) ? params["capital_cost_power"][p][y] : defaults["capital_cost_power"]
                    constrs["residual_value"][p,y] =
                    @constraint(
                        model,
                        vars["residual_value"][p,y] == vars["new_capacity"][p,y]* capital_cost_power *(1-(last_year-y+1)/lifetime) * discount_factor(input["years"][1],params["discount_rate"], last_year),
                        base_name="salvage_$(p)_$y"
                    )
                end
            end
        end
    end

    constrs["total_residual_value"] = @constraint(
        model,
        vars["total_residual_value"] == sum(
            vars["residual_value"][p, y] for p in keys(input["processes"]) for y in input["years"]
            if (input["years"][end] - y) < get(params["lifetime"],p,defaults["lifetime"])
        ),
        base_name = "total_residual_value"
    )

    constrs["power_balance"] = Dict()
    begin
        for t in input["tss"]
            for y in input["years"]
                for c in input["carriers"]
                    c == "Dummy" && continue
                    constrs["power_balance"][c,y,t] = @constraint(
                        model,
                        sum(vars["power_in"][p, y, t] for (p,io) in input["processes"] if io["carrier_in"] == c) == 
                        sum(vars["power_out"][p, y, t] for (p,io) in input["processes"] if io["carrier_out"] == c),
                        base_name="power_balance_$(c)_$(y)_$t"
                    )
                end
            end
        end
    end

    constrs["co2_emission_eq"] = Dict() 
    for y in input["years"]
        constrs["co2_emission_eq"][y] = @constraint(
            model,
            vars["annual_emission"][y] == sum(get(params["specific_co2"],p,defaults["specific_co2"]) * vars["total_energy_out"][p,y] for p in keys(input["processes"])),
            base_name = "co2_emission_eq_$(y)"
        )
    end

    constrs["co2_emission_limit"] = Dict()
    for y in input["years"]
        !haskey(params, "annual_co2_limit") && continue
        constrs["co2_emission_limit"][y] = @constraint(
            model,
            vars["annual_emission"][y] <= params["annual_co2_limit"][y],
            base_name = "co2_emission_limit_$y"
        )
    end

    constrs["efficiency"] = Dict()
    for p in keys(input["processes"])
        get(params["is_storage"],p,defaults["is_storage"]) && continue
        for y in input["years"]
            for t in input["tss"]
                constrs["efficiency"][p,y,t] = @constraint(
                    model,
                    vars["power_out"][p,y,t] == vars["power_in"][p,y,t] * get(params["efficiency"],p,defaults["efficiency"]),
                    base_name = "efficiency_eq_$(p)_$(y)_$t"
                )
            end
        end
    end

    # constrs[:max_power_out] = Dict()
    # for cp in keys(sets[:CP])
    #     haskey(params[:availability_profile], cp) && continue
    #     for y in sets[:Y]
    #         for t in sets[:T]
    #             constrs[:max_power_out][cp,y,t] = @constraint(
    #                 model,
    #                 vars[:PowerOut][cp, y, t] <= vars[:CapActive][cp, y],
    #                 base_name = "max_power_out_$(cp)_$(y)_$t"
    #             )
    #         end
    #     end
    # end

    constrs["re_availability"] = Dict()
    for p in keys(input["processes"])
        !haskey(params["availability_profile"], p) && continue
        for y in input["years"]
            for t in input["tss"]
                constrs["re_availability"][p,y,t] = @constraint(
                    model,
                    vars["power_out"][p,y,t] <= vars["active_capacity"][p,y] * params["availability_profile"][p][t],
                    base_name = "re_availability_$(p)_$(y)_$t"
                )
            end
        end
    end


    constrs["technical_availability"] = Dict()
    for p in keys(input["processes"])
        avail = get(params["technical_availability"],p,defaults["technical_availability"])
        for y in input["years"]
            for t in input["tss"]
                @constraint(
                    model,
                    vars["power_out"][p,y,t] <= vars["active_capacity"][p,y] * avail,
                    base_name = "technical_availability_$(p)_$(y)_$t"
                )
            end
        end
    end

    constrs["energy_out_time"] = Dict()
    for y in input["years"]
        for t in input["tss"]
            for p in keys(input["processes"])
                constrs["energy_out_time"][p,y,t] = @constraint(
                    model,
                    vars["energy_out_time"][p,y,t] == vars["power_out"][p,y,t] * (8760 /length(input["tss"])),
                    base_name = "energy_out_time_$(p)_$(y)_$t"
                )
            end
        end
    end

    constrs["energy_in_time"] = Dict()
    for y in input["years"]
        for t in input["tss"]
            for p in keys(input["processes"])
                constrs["energy_in_time"][p,y,t] = @constraint(
                    model,
                    vars["energy_in_time"][p,y,t] == vars["power_in"][p,y,t] * (8760 /length(input["tss"])),
                    base_name = "energy_in_time_$(p)_$(y)_$t"
                )
            end
        end
    end

    # Fraction Equations
    constrs["min_cosupply"] = Dict()
    for (p,io) in keys(input["processes"])
        !haskey(params["min_fraction_out"], p) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs["min_cosupply"][p,y,t] = @constraint(
                    model,
                    vars["energy_out_time"][p,y,t] >= params["min_fraction_out"][p][y] * vars["net_energy_generation"][io["carrier_out"],y,t],
                    base_name = "min_cosupply_$(p)_$(y)_$t"
                )
            end
        end
    end

    constrs["max_cosupply"] = Dict()
    for (cp,io) in keys(input["processes"])
        !haskey(params["max_fraction_out"], p) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs["max_cosupply"][p,y,t] = @constraint(
                    model,
                    vars["energy_out_time"][p,y,t] <= params["max_fraction_out"][p][y] * vars["net_energy_generation"][io["carrier_out"],y,t],
                    base_name = "max_cosupply_$(p)_$(y)_$t"
                )
            end
        end
    end

    constrs["min_couse"] = Dict()
    for (p,io) in keys(input["processes"])
        !haskey(params["min_fraction_in"], p) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs["min_couse"][p,y,t] = @constraint(
                    model,
                    vars["energy_in_time"][p,y,t] >= params["min_fraction_in"][p][y] * vars["net_energy_consumption"][io["carrier_in"],y,t],
                    base_name = "min_couse_$(p)_$(y)_$t"
                )
            end
        end
    end

    constrs["max_couse"] = Dict()
    for (p,io) in keys(input["processes"])
        !haskey(params["max_fraction_in"], p) && continue
        for y in input["years"]
            for t in input["tss"]
                constrs["max_couse"][p,y,t] = @constraint(
                    model,
                    vars["energy_in_time"][p,y,t] <= params["max_fraction_in"][p][y] * vars["net_energy_consumption"][io["carrier_in"],y,t],
                    base_name = "max_couse_$(p)_$(y)_$t"
                )
            end
        end
    end

    # Capacity
    constrs["max_legacy_cap"] = Dict()
    for p in keys(input["processes"])
        !haskey(params["max_legacy_capacity"], p) && continue
        for y in input["years"]
            isinf(params["max_legacy_capacity"][p][y]) && continue
            constrs["max_legacy_cap"][p,y] = @constraint(
                model,
                vars["legacy_capacity"][p,y] <= params["max_legacy_capacity"][p][y],
                base_name = "max_legacy_cap_$(p)_$y"
            )
        end
    end

    constrs["min_legacy_cap"] = Dict()
    for p in keys(input["processes"])
        !haskey(params["min_legacy_capacity"], p) && continue
        for y in input["years"]
            isinf(params["min_legacy_capacity"][p][y]) && continue
            constrs["min_legacy_cap"][p,y] = @constraint(
                model,
                vars["legacy_capacity"][p,y] >= params["min_legacy_capacity"][p][y],
                base_name = "min_legacy_cap_$(p)_$y"
            )
        end
    end

    constrs["active_capacity"] = Dict() 
    for p in keys(input["processes"])
        lifetime = get(params["lifetime"],p,defaults["lifetime"])
        for y in input["years"]
            constrs["active_capacity"][p,y] = @constraint(
                model,
                vars["active_capacity"][p,y] == vars["legacy_capacity"][p,y] + sum(
                    vars["new_capacity"][p,yy] 
                    for yy in input["years"] 
                    if yy in y-lifetime+1:y
                ),
                base_name = "active_capacity_$(p)_$y"
            )
        end
    end

    constrs["max_active_capacity"] = Dict()
    for p in keys(input["processes"])
        !haskey(params["max_capacity"],p) && continue
        for y in input["years"]
            isinf(params["max_capacity"][p][y]) && continue
            constrs["max_active_capacity"][p,y] = @constraint(
                model,
                vars["active_capacity"][p,y] <= params["max_capacity"][p][y],
                base_name = "max_active_capacity$(p)_$y"
            )
        end
    end

    constrs["min_active_capacity"] = Dict()
    for p in keys(input["processes"])
        !haskey(params["min_capacity"],p) && continue
        for y in input["years"]
            isinf(params["min_capacity"][p][y]) && continue
            constrs["min_active_capacity"][p,y] = @constraint(
                model,
                vars["active_capacity"][p,y] >= params["min_capacity"][p][y],
                base_name = "min_active_capacity$(p)_$y"
            )
        end
    end

    # Energy
    constrs["energy_power_out"] = Dict() 
    for p in keys(input["processes"])
        haskey(params["output_profile"],p) && continue
        for y in input["years"]
            constrs["energy_power_out"][p,y] = @constraint(
                model,
                vars["total_energy_out"][p,y] == sum(vars["energy_out_time"][p,y,t] for t in input["tss"]),
                base_name = "energy_power_out_$(p)_$y"
            )
        end
    end
    
    constrs["energy_power_in"] = Dict()
    for p in keys(input["processes"])
        for y in input["years"]
            constrs["energy_power_in"][p,y] = @constraint(
                model,
                vars["total_energy_out"][p,y] == sum(vars["energy_in_time"][p,y,t] for t in input["tss"]),
                base_name = "energy_power_in_$(p)_$y"
            )
        end
    end

    constrs["max_energy_out"] = Dict()
    for p in keys(input["processes"])
        !haskey(params["max_energy_out"], p) && continue
        for y in input["years"]
            constrs["max_energy_out"][p,y] = @constraint(
                model,
                vars["total_energy_out"][cp, y] <= params["max_energy_out"][p][y],
                base_name = "max_energy_out_$(p)_$y"
            )
        end
    end

    constrs["min_energy_out"] = Dict()
    for p in keys(input["processes"])
        !haskey(params["min_energy_out"], p) && continue
        for y in input["years"]
            constrs["min_energy_out"][p,y] = @constraint(
                model,
                vars["total_energy_out"][p,y] >= params["min_energy_out"][p][y],
                base_name = "min_energy_out_$(p)_$y"
            )
        end
    end

    constrs["load_shape"] = Dict()
    for cp in keys(input["processes"])
        !haskey(params["output_profile"],p) && continue
        for y in input["years"]
            for t in input["tss"]
                constrs["load_shape"][p,y,t] = @constraint(
                    model,
                    vars["energy_out_time"][p,y,t] == params["output_profile"][p][t] * vars["total_energy_out"][p,y],
                    base_name = "load_shape_$(p)_$(y)_$t"
                )
            end
        end
    end

    constrs["net_to_gen"] = Dict()
    for c in input["carriers"]
        for y in input["years"]
            for t in input["tss"]
                constrs["net_to_gen"][c,y,t] = @constraint(
                    model,
                    vars["net_energy_generation"][c,y,t] == sum(vars["energy_out_time"][p,y,t] for (p,io) in input["processes"] if io["carrier_out"] == c),
                    base_name = "net_to_gen_$(c)_$(y)_$t"
                )
            end
        end
    end

    constrs["net_to_con"] = Dict()
    for c in input["carriers"]
        for y in input["years"]
            for t in input["tss"]
                constrs["net_to_con"][c,y,t] = @constraint(
                    model,
                    vars["net_energy_consumption"][c,y,t] == sum(vars["energy_in_time"][p,y,t] for (p,io) in input["processes"] if io["carrier_in"] == c),
                    base_name = "net_to_con_$(c)_$(y)_$t"
                )
            end
        end
    end

    # Storage
    constrs["storage_energy_limit"] = Dict()
    for p in keys(input["processes"])
        !haskey(params["is_storage"], p) && continue
        for y in input["years"]
            for t in input["tss"]
                constrs["storage_energy_limit"][p,y,t] = @constraint(
                    model,
                    vars["storage_level"][p,y,t] <= vars["max_storage_level"][p,y],
                    base_name = "storage_energy_limit_$(p)_$(y)_$t"
                )
            end
        end
    end


    constrs["charge_power_limit"] = Dict()
    for cp in keys(input["processes"])
        !haskey(params["is_storage"], p) && continue
        for y in input["years"]
            for t in input["tss"]
                constrs["charge_power_limit"][p,y,t] = @constraint(
                    model,
                    vars["power_in"][p,y,t] <= vars["active_capacity"][p,y],
                    base_name = "charge_power_limit_$(p)_$(y)_$t"
                )
            end
        end
    end

    constrs["storage_energy_balance"] = Dict()
    for p in keys(input["processes"])
        !haskey(params["is_storage"], p) && continue
        eff = params["efficiency"][p]
        eff_charge = params["charge_efficiency"][p]
        for y in input["years"]
            for (idx,t) in enumerate(input["tss"])
                prev_t = input["tss"][idx == 1 ? end : idx - 1]
                constrs["storage_energy_balance"][p,y,t] = @constraint(
                    model,
                    vars["storage_level"][p,y,t] == vars["storage_level"][p,y,prev_t]
                    + vars["power_in"][p,y,t] * params["dt"] * eff_charge
                    - vars["power_out"][p,y,t] * params["dt"] / eff,
                    base_name = "storage_energy_balance_$(p)_$(y)_$t"
                )
            end
        end
    end

    constrs["c_rate_relation"] = Dict()
    for cp in keys(input["processes"])
        !haskey(params["is_storage"], p) && continue
        for y in input["years"]
            constrs["c_rate_relation"][p,y] = @constraint(
                model,
                vars["max_storage_level"][p,y] == vars["active_capacity"][p,y] / params["c_rate"][p],
                base_name = "c_rate_relation_$(p)_$y"
            )
        end
    end

    return constrs
end

function set_obj!(model, vars)
    @objective(model, Min, vars[:TOTEX])
end

function get_output(input::Input, vars)::Dictionary
    output = Dictionary()
    for (var_name, attributes) in variables
        output[var_name] = Dictionary()
        set_names = attributes.sets
        if length(set_names) > 0
            sets = [input[:sets][set_name] for set_name in set_names]
            for index_tuple in Iterators.product(sets...)
                var_value = value(vars[var_name][index_tuple])
                if (!has_key(attributes, :default) || var_value != attributes.default)
                    output[var_name][index_tuple...] = var_value
                end
            end
        else
            var_value = value(vars[var_name])
            if (!has_key(attributes, :default) || var_value != attributes.default)
                output[var_name] = var_value
            end
        end
    end
end

end