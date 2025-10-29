module PADM


# include("../core/CESM.jl")
using ..CESM
using ..CESM.Model
using JuMP, Dualization, Gurobi

DUALITY_GAP_THRESHOLD = 0.001
CONVERGENCE_THRESHOLD = 0.001
INITIAL_MU = .001
INCREASE_RATE = 0.05
MANIPULATION_LIMIT = 0.1
MU_INCREASE_FACTOR = 2
MAX_INNER_ITER = 40
MAX_OUTER_ITER = 100

CHANGED_PROFILE_PROCESS = "Demand_Electricity"
CHANGED_CAPACITY_PROCESS = "PP_PV"




function add_upper_vars(input, primal_model)
    upper_vars = Dict()
    upper_vars["delta"] = Dict(
        t => @variable(primal_model, base_name= "upper_delta" * "_" * string(t)) for t in input.timesteps
    )
    upper_vars["abs"] = Dict(
        t => @variable(primal_model, base_name= "upper_abs" * "_" * string(t), lower_bound=0) for t in input.timesteps
    )
    upper_vars["obj"] = @variable(primal_model, base_name="upper_obj", lower_bound=0)
    return upper_vars
end

function add_upper_constrs(input,primal_model,upper_vars, changed_profile_process)
    @constraint(primal_model, upper_vars["obj"] == sum(upper_vars["abs"][t] for t in input.timesteps), base_name="upper_obj_sum")
    for t in input.timesteps
        @constraint(primal_model, upper_vars["abs"][t] >= upper_vars["delta"][t], base_name="abs_upper_bound_$(t)")
        @constraint(primal_model, upper_vars["abs"][t] >= -upper_vars["delta"][t], base_name="abs_lower_bound_$(t)")
        @constraint(primal_model, upper_vars["abs"][t] <= MANIPULATION_LIMIT, base_name="manipulation_limit_$(t)")
    end
    @constraint(primal_model, sum(upper_vars["delta"][t] * get_parameter(input,"output_profile",(changed_profile_process,t)) for t in input.timesteps)==0, base_name="total_change")
end

function add_manipulation_constrs(input,primal_model,primal_vars,changed_capacity_process, capacity)
    @constraint(primal_model, sum(primal_vars["new_capacity"][changed_capacity_process,y] for y in input.years if Int(y)<=2050) >= capacity * (1+INCREASE_RATE), base_name="capacity_change")
end

function set_primal_constrs(input, primal_model, primal_vars, upper_vars, primal_constrs, changed_profile_process)
    # manipulates the primal constraints to include the upper-level variables
    for y in input.years
        for t in input.timesteps
            primal_constrs["load_shape"][changed_profile_process,y,t] = @constraint(
                primal_model,
                primal_vars["energy_out_time"][changed_profile_process,y,t] == get_parameter(input,"output_profile",(changed_profile_process,t)) * get_parameter(input,"min_energy_out",(changed_profile_process,y)) * (1+upper_vars["delta"][t]),
                base_name = "load_shape_$(changed_profile_process)_$(y)_$(t)"
            )
        end
    end
end

function get_dual_vars(input, dual_model, changed_profile_process)
    dual_vars = Dict()
    for y in input.years
        for t in input.timesteps
            dual_vars[y,t] = variable_by_name(dual_model, "dual_var_load_shape_$(changed_profile_process)_$(y)_$(t)")
        end
    end
    return dual_vars
end


function update_primal_objective(input, mu, dual_vars, primal_model, primal_obj, upper_vars, upper_obj, changed_profile_process)
    dual_expr = sum(value(dual_vars[y,t]) * get_parameter(input,"output_profile",(changed_profile_process,t)) * get_parameter(input,"min_energy_out",(changed_profile_process,y)) * (1+upper_vars["delta"][t]) for y in input.years for t in input.timesteps)
    @objective(primal_model, Min, upper_obj + mu * (primal_obj-dual_expr))
end

function update_dual_obj(input, dual_model, upper_values, dual_vars, changed_profile_process)
    println(objective_sense(dual_model))
    println(objective_function(dual_model))
    for y in input.years
        for t in input.timesteps
            set_objective_coefficient(dual_model, dual_vars[y,t], get_parameter(input,"output_profile",(changed_profile_process,t)) * get_parameter(input,"min_energy_out",(changed_profile_process,y)) * (1+upper_values[t]))
        end
    end
end


function PADM_alg(input)
    changed_profile_process =  first(filter(p -> p.name == CHANGED_PROFILE_PROCESS, input.processes))
    changed_capacity_process = first(filter(p -> p.name == CHANGED_CAPACITY_PROCESS, input.processes))

    (primal_model,primal_vars,primal_constrs) = CESM.Model.build_model(input)
    # set_attribute(primal_model, "OutputFlag", 0)
    optimize!(primal_model)
    output = CESM.Model.get_output(input, primal_vars)
    
    capacity = sum(get(output["new_capacity"],(changed_capacity_process,y),0) for y in input.years if Int(y)<=2050)

    
    dual_model = dualize(primal_model,Gurobi.Optimizer; dual_names = DualNames("dual_var_", "dual_con_"))
    dual_vars = get_dual_vars(input, dual_model, changed_profile_process)
    dual_obj = objective_function(dual_model)
    set_attribute(dual_model, "Method", 2)
    # set_attribute(dual_model, "OutputFlag", 0)
    optimize!(dual_model)
    
    output_profile = input.parameters["output_profile"][changed_profile_process] 
    delete!(input.parameters["output_profile"],changed_profile_process)
    (primal_model,primal_vars,primal_constrs) = CESM.Model.build_model(input)
    input.parameters["output_profile"][changed_profile_process] = output_profile
    primal_obj = objective_function(primal_model)
    # set_attribute(primal_model, "OutputFlag", 0)
    upper_vars = add_upper_vars(input, primal_model)
    upper_obj = upper_vars["obj"]
    add_upper_constrs(input, primal_model, upper_vars, changed_profile_process)
    add_manipulation_constrs(input,primal_model,primal_vars,changed_capacity_process, capacity)
    set_primal_constrs(input, primal_model, primal_vars, upper_vars, primal_constrs, changed_profile_process)
    optimize!(primal_model)
    println("solve finished !!!!!!####")

    mu = INITIAL_MU
    upper_values = Dict(t => 0 for t in input.timesteps)
    println("algorithm started")
    while true
        while true
            update_primal_objective(input, mu, dual_vars, primal_model, primal_obj, upper_vars, upper_obj, changed_profile_process)
            optimize!(primal_model)
            update_dual_obj(input, dual_model, upper_values, dual_vars, changed_profile_process)
            optimize!(dual_model)
            if maximum(values(Dict(t => abs(value(upper_vars["delta"][t]) - upper_values[t]) for t in input.timesteps))) < CONVERGENCE_THRESHOLD
                break
            else
                upper_values = Dict(t => value(upper_vars["delta"][t]) for t in input.timesteps)
            end
        end
        if (value(primal_obj) - value(dual_obj)) < DUALITY_GAP_THRESHOLD
            break
        else
            mu *= MU_INCREASE_FACTOR
        end
    end
    return upper_values
end

end