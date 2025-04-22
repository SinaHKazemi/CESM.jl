module Model

using JuMP, HiGHS, Gurobi
include("variables.jl")
using .Variables

export run_cesm

variables = Variables.variables

function run_cesm(input)
    model = JuMP.Model(Gurobi.Optimizer)
    vars = add_vars!(model, input)
    add_constraints!(model, vars, input)
    set_obj!(model, vars)
    # write_to_file(model, "model.mps")
    optimize!(model)
    # grb_model = model.moi_backend.optimizer.model.inner
    compute_conflict!(model)
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
    

    iis_model, _ = copy_conflict(model)
    print(iis_model)
    output = get_output(input, vars)
    return output
end


# add variables
function add_vars!(model, input)::Dict
    vars = Dict()
    for (var_name, attributes) in variables
        set_names = attributes.sets
        if length(set_names) > 1
            sets = Vector()
            for set_name in set_names
                collection = input[:sets][set_name]
                if collection isa Dict
                    push!(sets, keys(collection))
                else
                    push!(sets, collection)
                end
            end
            vars[var_name] = Dict(
                index_tuple => @variable(model, base_name= string(var_name) * "_" * join(index_tuple, "_"), lower_bound=0)
                for index_tuple in Iterators.product(sets...)
            )
        elseif length(set_names) == 1
            vars[var_name] = Dict(
                index => @variable(model, base_name= string(var_name) * "_" * string(index), lower_bound=0)
                for index in input[:sets][set_names[1]]
            )                    
        else
            vars[var_name] = @variable(model, base_name= string(var_name), lower_bound=0)
        end
    end
    return vars
end


# helper function
function discount_factor(input, y::Int)::Float64
    y_start = input[:sets][:Y][1]
    return (1 + input[:params][:discount_rate]^(y_start - y))
end

function year_gap(input, y::Int)::Int
    years = input[:sets][:Y]
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



function  add_constraints!(model, vars, input)::Dict
    # add constraints
    constrs = Dict()
    params = input[:params]
    defaults = input[:defaults]
    sets = input[:sets]
    constrs[:totex] = @constraint(model, vars[:TOTEX] == vars[:CAPEX] + vars[:OPEX], base_name="totex")
    constrs[:capex] = @constraint(
        model,
        vars[:CAPEX] == sum(
            discount_factor(input, y) * 
            sum(vars[:CapNew][cp,y]) * (haskey(params[:capex_cost_power],cp) ? params[:capex_cost_power][cp][y]  : defaults[:capex_cost_power]) for cp in keys(sets[:CP])
            for y in sets[:Y]
        ) - vars[:TotalSalvage],
        base_name = "capex"
    )

    constrs["opex"] = @constraint(
        model,
        vars[:OPEX] == sum(
            (
                (
                    vars[:CapActive][cp, y] * (haskey(params[:opex_cost_power],cp) ? params[:opex_cost_power][cp][y] : defaults[:opex_cost_power]) +
                    vars[:EnergyOutTot][cp, y] * (haskey(params[:opex_cost_energy],cp) ? params[:opex_cost_energy][cp][y] : defaults[:opex_cost_energy]) +
                    (haskey(params,:co2_price) ? params[:co2_price][y] : defaults[:co2_price]) * vars[:AnnualEmission][y]
                ) * year_gap(input, y) * discount_factor(input, y)
            )
            for cp in keys(sets[:CP])
            for y in sets[:Y]
        ),
        base_name = "opex"
    )


    constrs[:salvage] = Dict()
    begin
        last_year = sets[:Y][end]
        for cp in keys(sets[:CP])
            lifetime = get(params[:technical_lifetime],cp,defaults[:technical_lifetime])
            for y in sets[:Y]
                if (last_year - y) < lifetime
                    technical_lifetime = haskey(params[:technical_lifetime],cp) ? params[:technical_lifetime][cp] : defaults[:technical_lifetime]
                    capex_cost_power = haskey(params[:capex_cost_power],cp) ? params[:capex_cost_power][cp][y] : defaults[:capex_cost_power]
                    constrs[:salvage][cp,y] =
                    @constraint(
                        model,
                        vars[:Salvage][cp, y] == vars[:CapNew][cp,y]* capex_cost_power *(1-(last_year-y+1)/technical_lifetime) * discount_factor(input,last_year),
                        base_name="salvage_$(cp)_$y"
                    )
                end
            end
        end
    end

    constrs[:salvage_tot] = @constraint(
        model,
        vars[:TotalSalvage] == sum(
            vars[:Salvage][cp, y] for cp in keys(sets[:CP]) for y in sets[:Y]
            if (sets[:Y][end] - y) < get(params[:technical_lifetime],cp,defaults[:technical_lifetime])
        ),
        base_name = "total_salvage"
    )

    constrs[:power_balance] = Dict()
    begin
        for t in sets[:T]
            for y in sets[:Y]
                for co in sets[:CO]
                    co == Symbol("Dummy") && continue
                    constrs[:power_balance][co,y,t] = @constraint(
                        model,
                        sum(vars[:PowerIn][cp, y, t] for (cp,io) in sets[:CP] if io.cin == co) == 
                        sum(vars[:PowerOut][cp, y, t] for (cp,io) in sets[:CP] if io.cout == co),
                        base_name="power_balance_$(co)_$(y)_$t"
                    )
                end
            end
        end
    end

    constrs[:co2_emission_eq] = Dict() 
    for y in sets[:Y]
        constrs[:co2_emission_eq][y] = @constraint(
            model,
            vars[:AnnualEmission][y] == sum(get(params[:spec_co2],cp,defaults[:spec_co2]) * vars[:EnergyOutTot][cp, y] for cp in keys(sets[:CP])),
            base_name = "co2_emission_eq_$y"
        )
    end

    constrs[:co2_emission_limit] = Dict()
    for y in sets[:Y]
        !haskey(params,:annual_co2_limit) && continue
        constrs[:co2_emission_limit][y] = @constraint(
            model,
            vars[:AnnualEmission][y] <= params[:annual_co2_limit][y],
            base_name = "co2_emission_limit_$y"
        )
    end

    constrs[:efficiency] = Dict()
    for cp in keys(sets[:CP])
        get(params[:is_storage],cp,defaults[:is_storage]) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:efficiency][cp,y,t] = @constraint(
                    model,
                    vars[:PowerOut][cp, y, t] == vars[:PowerIn][cp,y,t] * get(params[:efficiency],cp,defaults[:efficiency]),
                    base_name = "efficiency_eq_$(cp)_$(y)_$t"
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

    constrs[:re_availability] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:availability_profile], cp) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:re_availability][cp,y,t] = @constraint(
                    model,
                    vars[:PowerOut][cp, y, t] <= vars[:CapActive][cp, y] * params[:availability_profile][cp][t],
                    base_name = "re_availability_$(cp)_$(y)_$t"
                )
            end
        end
    end


    constrs[:technical_availability] = Dict()
    for cp in keys(sets[:CP])
        avail = get(params[:technical_availability],cp,defaults[:technical_availability])
        for y in sets[:Y]
            for t in sets[:T]
                @constraint(
                    model,
                    vars[:PowerOut][cp, y, t] <= vars[:CapActive][cp, y] * avail,
                    base_name = "technical_availability_$(cp)_$(y)_$t"
                )
            end
        end
    end

    constrs[:energy_out_time] = Dict()
    for y in sets[:Y]
        for t in sets[:T]
            for cp in keys(sets[:CP])
                constrs[:energy_out_time][cp,y,t] = @constraint(
                    model,
                    vars[:EnergyOutTime][cp, y, t] == vars[:PowerOut][cp, y, t] * (8760 /length(sets[:T])),
                    base_name = "energy_out_time_$(cp)_$(y)_$t"
                )
            end
        end
    end

    constrs[:energy_in_time] = Dict()
    for y in sets[:Y]
        for t in sets[:T]
            for cp in keys(sets[:CP])
                constrs[:energy_in_time][cp,y,t] = @constraint(
                    model,
                    vars[:EnergyInTime][cp, y, t] == vars[:PowerIn][cp, y, t] * (8760 /length(sets[:T])),
                    base_name = "energy_in_time_$(cp)_$(y)_$t"
                )
            end
        end
    end

    # Fraction Equations
    constrs[:min_cosupply] = Dict()
    for (cp,io) in sets[:CP]
        !haskey(params[:out_frac_min], cp) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:min_cosupply][cp,y,t] = @constraint(
                    model,
                    vars[:EnergyOutTime][cp, y, t] >= params[:out_frac_min][cp][y] * vars[:EnergyNetGen][io.cout,y,t],
                    base_name = "min_cosupply_$(cp)_$(y)_$t"
                )
            end
        end
    end

    constrs[:max_cosupply] = Dict()
    for (cp,io) in sets[:CP]
        !haskey(params[:out_frac_max], cp) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:max_cosupply][cp,y,t] = @constraint(
                    model,
                    vars[:EnergyOutTime][cp, y, t] <= params[:out_frac_max][cp][y] * vars[:EnergyNetGen][io.cout, y, t],
                    base_name = "max_cosupply_$(cp)_$(y)_$t"
                )
            end
        end
    end

    constrs[:min_couse] = Dict()
    for (cp,io) in sets[:CP]
        !haskey(params[:in_frac_min], cp) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:min_couse][cp,y,t] = @constraint(
                    model,
                    vars[:EnergyInTime][cp, y, t] >= params[:in_frac_min][cp][y] * vars[:EnergyNetCon][io.cin, y, t],
                    base_name = "min_couse_$(cp)_$(y)_$t"
                )
            end
        end
    end

    constrs[:max_couse] = Dict()
    for (cp,io) in sets[:CP]
        !haskey(params[:in_frac_max], cp) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:max_couse][cp,y,t] = @constraint(
                    model,
                    vars[:EnergyInTime][cp, y, t] <= params[:in_frac_max][cp][y] * vars[:EnergyNetCon][io.cin, y, t],
                    base_name = "max_couse_$(cp)_$(y)_$t"
                )
            end
        end
    end


    # Capacity
    constrs[:max_cap_res] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:cap_res_max], cp) && continue
        for y in sets[:Y]
            isinf(params[:cap_res_max][cp][y]) && continue
            constrs[:max_cap_res][cp,y] = @constraint(
                model,
                vars[:CapRes][cp, y] <= params[:cap_res_max][cp][y],
                base_name = "max_cap_res_$(cp)_$y"
            )
        end
    end

    constrs[:min_cap_res] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:cap_res_min], cp) && continue
        for y in sets[:Y]
            constrs[:min_cap_res][cp,y] = @constraint(
                model,
                vars[:CapRes][cp, y] >= params[:cap_res_min][cp][y],
                base_name = "min_cap_res_$(cp)_$y"
            )
        end
    end

    constrs[:cap_active] = Dict() 
    for cp in keys(sets[:CP])
        lifetime = get(params[:technical_lifetime],cp,defaults[:technical_lifetime])
        for y in sets[:Y]
            constrs[:cap_active][cp,y] = @constraint(
                model,
                vars[:CapActive][cp, y] == vars[:CapRes][cp, y] + sum(
                    vars[:CapNew][cp,yy] 
                    for yy in sets[:Y] 
                    if yy in y-lifetime+1:y
                ),
                base_name = "cap_active_$(cp)_$y"
            )
        end
    end

    constrs[:max_cap_active] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:cap_max], cp) && continue
        for y in sets[:Y]
            isinf(params[:cap_max][cp][y]) && continue
            constrs[:max_cap_active][cp,y] = @constraint(
                model,
                vars[:CapActive][cp, y] <= params[:cap_max][cp][y],
                base_name = "max_cap_active_$(cp)_$y"
            )
        end
    end

    constrs[:min_cap_active] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:cap_min], cp) && continue
        for y in sets[:Y]
            constrs[:min_cap_active][cp,y] = @constraint(
                model,
                vars[:CapActive][cp, y] >= params[:cap_min][cp][y],
                base_name = "min_cap_active_$(cp)_$y"
            )
        end
    end

    # Energy
    constrs[:energy_power_out] = Dict() 
    for cp in keys(sets[:CP])
        haskey(params[:output_profile],cp) && continue
        for y in sets[:Y]
            constrs[:energy_power_out][cp,y] = @constraint(
                model,
                vars[:EnergyOutTot][cp, y] == sum(vars[:EnergyOutTime][cp,y,t] for t in sets[:T]),
                base_name = "energy_power_out_$(cp)_$y"
            )
        end
    end
    
    constrs[:energy_power_in] = Dict()
    for cp in keys(sets[:CP])
        for y in sets[:Y]
            constrs[:energy_power_in][cp,y] = @constraint(
                model,
                vars[:EnergyInTot][cp, y] == sum(vars[:EnergyInTime][cp,y,t] for t in sets[:T]),
                base_name = "energy_power_in_$(cp)_$y"
            )
        end
    end

    constrs[:max_energy_out] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:max_eout], cp) && continue
        for y in sets[:Y]
            constrs[:max_energy_out][cp,y] = @constraint(
                model,
                vars[:EnergyOutTot][cp, y] <= params[:max_eout][cp][y],
                base_name = "max_energy_out_$(cp)_$y"
            )
        end
    end

    constrs[:min_energy_out] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:min_eout], cp) && continue
        for y in sets[:Y]
            constrs[:min_energy_out][cp,y] = @constraint(
                model,
                vars[:EnergyOutTot][cp, y] >= params[:min_eout][cp][y],
                base_name = "min_energy_out_$(cp)_$y"
            )
        end
    end

    constrs[:load_shape] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:output_profile],cp) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:load_shape][cp,y,t] = @constraint(
                    model,
                    vars[:EnergyOutTime][cp,y,t] == params[:output_profile][cp][t] * vars[:EnergyOutTot][cp,y],
                    base_name = "load_shape_$(cp)_$(y)_$t"
                )
            end
        end
    end

    constrs[:net_to_gen] = Dict()
    for co in sets[:CO]
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:net_to_gen][co,y,t] = @constraint(
                    model,
                    vars[:EnergyNetGen][co,y,t] == sum(vars[:EnergyOutTime][cp,y,t] for (cp,io) in sets[:CP] if io.cout == co),
                    base_name = "net_to_gen_$(co)_$(y)_$t"
                )
            end
        end
    end

    constrs[:net_to_con] = Dict()
    for co in sets[:CO]
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:net_to_con][co,y,t] = @constraint(
                    model,
                    vars[:EnergyNetCon][co,y,t] == sum(vars[:EnergyInTime][cp,y,t] for (cp,io) in sets[:CP] if io.cin == co),
                    base_name = "net_to_con_$(co)_$(y)_$t"
                )
            end
        end
    end

    # Storage
    constrs[:storage_energy_limit] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:is_storage], cp) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:storage_energy_limit][cp,y,t] = @constraint(
                    model,
                    vars[:StorageLevel][cp,y,t] <= vars[:StorageLevelMax][cp,y],
                    base_name = "storage_energy_limit_$(cp)_$(y)_$t"
                )
            end
        end
    end


    constrs[:charge_power_limit] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:is_storage], cp) && continue
        for y in sets[:Y]
            for t in sets[:T]
                constrs[:charge_power_limit][cp,y,t] = @constraint(
                    model,
                    vars[:PowerIn][cp,y,t] <= vars[:CapActive][cp,y],
                    base_name = "charge_power_limit_$(cp)_$(y)_$t"
                )
            end
        end
    end

    constrs[:storage_energy_balance] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:is_storage], cp) && continue
        eff = params[:efficiency][cp]
        eff_charge = params[:efficiency_charge][cp]
        for y in sets[:Y]
            for (idx,t) in enumerate(sets[:T])
                prev_t = sets[:T][idx == 1 ? end : idx - 1]
                constrs[:storage_energy_balance][cp,y,t] = @constraint(
                    model,
                    vars[:StorageLevel][cp,y,t] == vars[:StorageLevel][cp,y,prev_t]
                    + vars[:PowerIn][cp,y,t] * params[:dt] * eff_charge
                    - vars[:PowerOut][cp,y,t] * params[:dt] / eff,
                    base_name = "storage_energy_balance_$(cp)_$(y)_$t"
                )
            end
        end
    end

    constrs[:c_rate_relation] = Dict()
    for cp in keys(sets[:CP])
        !haskey(params[:is_storage], cp) && continue
        for y in sets[:Y]
            constrs[:c_rate_relation][cp,y] = @constraint(
                model,
                vars[:Storagelevelmax][cp,y] == vars[:CapActive][cp,y] / params[:c_rate][cp],
                base_name = "c_rate_relation_$(cp)_$y"
            )
        end
    end

    return constrs
end

function set_obj!(model, vars)
    @objective(model, Min, vars[:TOTEX])
end

function get_output(input, vars)::Dict
    output = Dict()
    for (var_name, attributes) in variables
        output[var_name] = Dict()
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