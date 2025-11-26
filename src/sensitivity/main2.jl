
# PALM algorithm
using JuMP, Dualization, Gurobi



include("../core/CESM.jl")
using .CESM

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

function start()
    input = CESM.Parser.parse_input("./examples/House/config.json");
    timesteps = input.timesteps
    years = input.years
    (model,vars,constraints) = CESM.Model.build_model(input)
    CESM.Model.optimize_model(model)    
    println(objective_value(model))
    output = CESM.Model.get_output(input, vars)
    Battery = first(filter(p -> p.name == "Battery", input.processes))
    BATTERY_CAPACITY = sum(get(output["new_capacity"],(Battery,y),0) for y in years if Int(y)<=2050)
    println(BATTERY_CAPACITY)
    PP_Wind = first(filter(p -> p.name == "PP_Wind", input.processes))
    Battery = first(filter(p -> p.name == "Battery", input.processes))


    dual_model = dualize(model,Gurobi.Optimizer; dual_names = DualNames("dual_var_", "dual_con_"))
    # optimize!(dual_model)
    dual_obj = objective_function(dual_model)
    (model,vars,constrs) = CESM.Model.build_model(input,dual_model)
    primal_obj = objective_function(model)
    # set_attribute(model, "Crossover", 0)
    # set_attribute(model, "Method", 2)
    set_attribute(model, "OutputFlag", 0)
    set_attribute(model, "BarHomogeneous", 1)

    function get_param(param_name, keys)
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

    function has_param(param_name, keys)
        return get_param(param_name, keys) !== nothing
    end

    vars["delta"] = Dict(index => @variable(model, base_name= "delta" * "_" * string(index)) for index in timesteps)
    vars["ddelta"] = Dict(index => @variable(model, base_name= "ddelta" * "_" * string(index)) for index in timesteps)
    vars["abs_delta"] = Dict(index => @variable(model, base_name= "abs_delta" * "_" * string(index)) for index in timesteps)
    vars["dual"] = Dict(index_tuple => variable_by_name(model, "dual_var_renewable_availability_$(PP_Wind)_$(index_tuple[1])_$(index_tuple[2])") for index_tuple in Iterators.product(years,timesteps)) 

    params = Dict()
    params["cap"] =  Dict(index => @variable(model, base_name= "cap_param" * "_" * string(index), set = Parameter(0.0)) for index in years)
    params["delta"] =  Dict(index => @variable(model, base_name= "delta_param" * "_" * string(index), set = Parameter(0.0)) for index in timesteps)
    params["dual"] = Dict(index_tuple => @variable(model, base_name= "dual_param" * "_" * join(index_tuple, "_"), set = Parameter(0.0)) for index_tuple in Iterators.product(years,timesteps))
    params["trust_region_radius"] = @variable(model, base_name= "trust_region_radius", set = Parameter(0.0))

    for t in timesteps
        @constraint(model, vars["delta"][t] == vars["ddelta"][t] + params["delta"][t], base_name="delta_ddelta_$(t)")
    end

    for t in timesteps
        @constraint(model, vars["delta"][t] >= -0.1, base_name="delta_lowerbound_$(t)")
        @constraint(model, vars["delta"][t] <= 0.1, base_name="delta_upperbound_$(t)")
        @constraint(model, vars["abs_delta"][t] >= vars["delta"][t], base_name="abs_delta_lowerbound_$(t)")
        @constraint(model, vars["abs_delta"][t] >= -vars["delta"][t], base_name="abs_delta_upperbound_$(t)")
        @constraint(model, vars["abs_delta"][t] >= 0, base_name="abs_delta_zero_bound_$(t)")
        @constraint(model, vars["ddelta"][t] <= params["trust_region_radius"], base_name="ddelta_upperbound_$(t)")
        @constraint(model, -vars["ddelta"][t] <= params["trust_region_radius"], base_name="ddelta_lowerbound_$(t)")
    end
    @constraint(model, sum(vars["delta"][t]* get_param("availability_profile",(PP_Wind,t)) for t in timesteps) == 0, base_name="zero_sum")

    MU = 1

    @objective(model, Min, sum(vars["abs_delta"][t] for t in timesteps) + MU * (primal_obj-dual_obj))
    @constraint(model, sum(vars["new_capacity"][Battery,y] for y in years if Int(y)<=2050) >= BATTERY_CAPACITY * 1.5, base_name="battery_increase")

    for y in years
        for t in timesteps
            delete(model, constrs["renewable_availability"][PP_Wind,y,t])
            constrs["renewable_availability"][PP_Wind,y,t] = @constraint(
                model,
                vars["power_out"][PP_Wind,y,t] <= (vars["active_capacity"][PP_Wind,y] * (1 + params["delta"][t]) + params["cap"][y] * vars["ddelta"][t]) * get_param("availability_profile",(PP_Wind,t)),
                base_name = "renewable_availability_$(PP_Wind)_$(y)_$(t)"
            )
        end
    end

    for y in years
        con = constraint_by_name(model, "dual_con_active_capacity_$(PP_Wind)_$(y)")
        f = JuMP.constraint_object(con).func + sum(vars["dual"][y,t] * params["delta"][t] * get_param("availability_profile",(PP_Wind,t)) for t in timesteps) + sum(params["dual"][y,t] * vars["ddelta"][t] * get_param("availability_profile",(PP_Wind,t)) for t in timesteps)
        delete(model, con)
        @constraint(model, f>=0, base_name="dual_con_active_capacity_$(PP_Wind)_$(y)")
    end

    # set parameters to zero
    for y in years
        set_parameter_value(params["cap"][y], 0)
    end

    for t in timesteps
        set_parameter_value(params["delta"][t], 0)
    end

    for y in years
        for t in timesteps
            set_parameter_value(params["dual"][y,t], 0)
        end
    end

    # fix variables at zero
    for t in timesteps
        fix(vars["delta"][t], 0)
        fix(vars["ddelta"][t], 0)
        fix(vars["abs_delta"][t], 0)
    end

    optimize!(model)
    println(sum(value(vars["new_capacity"][Battery,y]) for y in years))
    println(value(primal_obj))

    dual_values = Dict((y,t) => value(vars["dual"][y,t]) for y in years, t in timesteps)
    cap_values = Dict(y => value(vars["active_capacity"][PP_Wind,y]) for y in years)
    delta_values = Dict(t => 0.0 for t in timesteps)

    for t in timesteps
        set_parameter_value(params["delta"][t], 0)
        for y in years
            set_parameter_value(params["dual"][y,t], dual_values[(y,t)])
        end
    end
    for y in years
        set_parameter_value(params["cap"][y], cap_values[y])
    end

    for t in timesteps
        unfix(vars["delta"][t])
        unfix(vars["ddelta"][t])
        unfix(vars["abs_delta"][t])
    end
    obj_value = Inf64

    initial_trust_region_radius = 0.02
    trust_region_radius = initial_trust_region_radius
    set_parameter_value(params["trust_region_radius"], trust_region_radius)

    i = 0
    while true
        i += 1
        println("Outer Iteration: ", i)
        j = 0
        while true
            j += 1
            println("Inner Iteration: ", j)
                    # unfix the upper-level variables
            for t in timesteps
                set_parameter_value(params["delta"][t], delta_values[t])
                if is_fixed(vars["delta"][t])
                    unfix(vars["delta"][t])
                end
                if is_fixed(vars["ddelta"][t])
                    unfix(vars["ddelta"][t])
                end
                if is_fixed(vars["abs_delta"][t])
                    unfix(vars["abs_delta"][t])
                end
            end
            optimize!(model)
            if maximum([abs(value(vars["ddelta"][t])) for t in timesteps]) < 1e-6
                println("Delta values converged in inner loop")
                break
            end
            new_delta_values = Dict(t => value(vars["delta"][t]) for t in timesteps)
            println("New delta values: ", maximum(values(new_delta_values)))


            # fix the upper-level variables
            abs_delta_values = Dict(t => value(vars["abs_delta"][t]) for t in timesteps)
            for t in timesteps
                set_parameter_value(params["delta"][t], new_delta_values[t])
                fix(vars["delta"][t], new_delta_values[t])
                fix(vars["ddelta"][t], 0)
                fix(vars["abs_delta"][t], abs_delta_values[t])
            end
            optimize!(model)
            println("primal obj after fixing: ", value(primal_obj))
            println("dual obj after fixing: ", value(dual_obj))

            # check for feasibility
            if termination_status(model) == MOI.INFEASIBLE_OR_UNBOUNDED || termination_status(model) == MOI.INFEASIBLE
                println("Infeasible solution in inner loop, adjusting...")
                trust_region_radius /= 2
                set_parameter_value(params["trust_region_radius"], trust_region_radius)
                continue
            else
                println("Feasible solution")
                println("Change in objective value: ", obj_value - objective_value(model))
                println("Sum of delta: ", sum(abs(new_delta_values[t]-delta_values[t]) for t in timesteps))
                if (obj_value - objective_value(model)) / sum(abs(value(vars["ddelta"][t])) for t in timesteps) < 1e-6
                    trust_region_radius /= 2
                    set_parameter_value(params["trust_region_radius"], trust_region_radius)
                    continue
                end
                # adjust delta values or other parameters as needed
                dual_values = Dict((y,t) => value(vars["dual"][y,t]) for y in years, t in timesteps)
                cap_values = Dict(y => value(vars["active_capacity"][PP_Wind,y]) for y in years)
                for t in timesteps
                    for y in years
                        set_parameter_value(params["dual"][y,t], dual_values[(y,t)])
                    end
                end
                for y in years
                    set_parameter_value(params["cap"][y], cap_values[y])
                end
                for t in timesteps
                    set_parameter_value(params["delta"][t], new_delta_values[t])
                end
                delta_values = new_delta_values
                obj_value = objective_value(model)
                trust_region_radius = min(trust_region_radius * 2, initial_trust_region_radius)
                set_parameter_value(params["trust_region_radius"], trust_region_radius)
            end
        end
        if value(primal_obj) - value(dual_obj) < 1e-4
            println("Converged in outer loop")
            break
        end
        
        MU *= 2
        trust_region_radius = initial_trust_region_radius
        set_parameter_value(params["trust_region_radius"], trust_region_radius)
        @objective(model, Min, sum(vars["abs_delta"][t] for t in timesteps) + MU * (primal_obj-dual_obj))
        obj_value = Inf64
        
    end
end


start()


# set the parameters
# solve the problem
# save the output (1)
# update the parameters (2)
    # delta to the new variable, cap to the new cap, dual to the new dual
# fix the upper level variables
    # delat at what it is and ddelta at zero
# resolve the problem to get feasible solutions
    # if infeasible go back to (1)
    # check if it satisfies the improvement criteria
    # if not go back to step (1)  else go to 
# check the improvements 

# function my_callback(cb_data, cb_where)
#     status = callback_node_status(cb_data, model)
#     if status == MOI.CALLBACK_NODE_STATUS_INTEGER
#         Gurobi.
#         obj_val = callback_objective_value(cb_data)
#         println("obj=$(obj_val)")
#     end
# end

# set_attribute(model, Gurobi.CallbackFunction(), my_callback)

# optimize!(model)
