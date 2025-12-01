module PADM

# include("../core/CESM.jl")
using ..CESM
using ..CESM.Model
using JuMP, Dualization, Gurobi

# DUALITY_GAP_THRESHOLD = 0.05
# CONVERGENCE_THRESHOLD = 0.01
# CONVERGENCE_OBJ = 1e-4
# INITIAL_MU = .1
# INCREASE_RATE = 0.10
# MANIPULATION_LIMIT = 0.14
# MU_INCREASE_FACTOR = 2
# MAX_INNER_ITER = 40
# MAX_OUTER_ITER = 30

# CHANGED_PROFILE_PROCESS = "Demand_Electricity"
# CHANGED_CAPACITY_PROCESS = "PP_PV"


struct Setting
    config_file::String
    manipulation_bound::Float64 # 0.1
    manipulated_cp::String # "Battery"
    target_cp::String # "PP_Wind" it has to be a renwewable
    target_change::Float64 # 0.2
    init_mu::Float64 # 1.0
    init_trust_region_radius::Float64 # 0.05
    min_stationary_change::Float64 # 1e-4
    min_obj_improvement_rate::Float64 # 1e-2
    last_year::Int64 # 2050
    duality_gap_tolerance::Float64 # 1e-2
    max_outer_iterations::Int64
    max_inner_iterations::Int64
    log_folder_path::String
end




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
        @constraint(primal_model, upper_vars["abs"][t] <= setting.manipulation_bound, base_name="manipulation_bound_$(t)")
    end
    # @constraint(primal_model, sum(upper_vars["delta"][t] * get_parameter(input,"output_profile",(changed_profile_process,t)) for t in input.timesteps)==0, base_name="total_change")
end

function add_manipulation_constrs(input,primal_model,primal_vars,changed_capacity_process, capacity)
    @constraint(primal_model, sum(primal_vars["new_capacity"][changed_capacity_process,y] for y in input.years if Int(y)<=2050) >= capacity * (1+setting.target_change), base_name="capacity_change")
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

function set_primal_constrs(input, primal_model, primal_vars, primal_constrs, changed_profile_process)
    for y in input.years
        for t in input.timesteps
            primal_constrs["load_shape"][changed_profile_process,y,t] = @constraint(
                primal_model,
                primal_vars["energy_out_time"][changed_profile_process,y,t] == get_parameter(input,"output_profile",(changed_profile_process,t)) * get_parameter(input,"min_energy_out",(changed_profile_process,y)),
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
    for y in input.years
        for t in input.timesteps
            set_objective_coefficient(dual_model, dual_vars[y,t], get_parameter(input,"output_profile",(changed_profile_process,t)) * get_parameter(input,"min_energy_out",(changed_profile_process,y)) * (1+upper_values[t]))
        end
    end
end

function check_obj_coeff(input, dual_model, dual_vars, changed_profile_process)
    f = objective_function(dual_model)
    for y in input.years
        for t in input.timesteps
            if get_parameter(input,"output_profile",(changed_profile_process,t)) * get_parameter(input,"min_energy_out",(changed_profile_process,y)) == coefficient(f, dual_vars[y,t])
                println(get_parameter(input,"output_profile",(changed_profile_process,t)) * get_parameter(input,"min_energy_out",(changed_profile_process,y)))
                println(coefficient(f, dual_vars[y,t]))
                println(y)
                println(t)
            end
        end
    end
end


function test_primal(input, input_without_profile, changed_profile_process, upper_values)
    input = deepcopy(input)
    for t in input.timesteps
        input.parameters["output_profile"][changed_profile_process][t] *= (1+ upper_values[t])
    end
    (primal_model,primal_vars,primal_constrs) = CESM.Model.build_model(input_without_profile)
    set_primal_constrs(input, primal_model, primal_vars, primal_constrs, changed_profile_process)
    set_attribute(primal_model, "OutputFlag", 0)
    optimize!(primal_model)
    output = CESM.Model.get_output(input, primal_vars)
    # capacity = sum(get(output["new_capacity"],(changed_capacity_process,y),0) for y in input.years if Int(y)<=2050)
    # println(capacity)
    println("primal test: $(objective_value(primal_model))")
end


function PADM_alg(input)
    changed_profile_process =  first(filter(p -> p.name == setting.manipulated_cp, input.processes))
    changed_capacity_process = first(filter(p -> p.name == setting.target_cp, input.processes))

    input_without_profile = deepcopy(input)
    delete!(input_without_profile.parameters["output_profile"],changed_profile_process)


    (primal_model,primal_vars,primal_constrs) = CESM.Model.build_model(input_without_profile)
    set_primal_constrs(input, primal_model, primal_vars, primal_constrs, changed_profile_process)
    set_attribute(primal_model, "OutputFlag", 0)
    optimize!(primal_model)
    output = CESM.Model.get_output(input, primal_vars)
    
    capacity = sum(get(output["new_capacity"],(changed_capacity_process,y),0) for y in input.years if Int(y)<=2050)
    println(capacity)

    
    dual_model = dualize(primal_model,Gurobi.Optimizer; dual_names = DualNames("dual_var_", "dual_con_"))
    dual_vars = get_dual_vars(input, dual_model, changed_profile_process)
    dual_obj = objective_function(dual_model)
    set_attribute(dual_model, "Method", 2)
    set_attribute(dual_model, "OutputFlag", 0)
    optimize!(dual_model)
    

    (primal_model,primal_vars,primal_constrs) = CESM.Model.build_model(input_without_profile)
    primal_obj = objective_function(primal_model)
    set_attribute(primal_model, "OutputFlag", 0)
    upper_vars = add_upper_vars(input, primal_model)
    upper_obj = upper_vars["obj"]
    add_upper_constrs(input, primal_model, upper_vars, changed_profile_process)
    add_manipulation_constrs(input,primal_model,primal_vars,changed_capacity_process, capacity)
    set_primal_constrs(input, primal_model, primal_vars, upper_vars, primal_constrs, changed_profile_process)
    optimize!(primal_model)

    mu = setting.init_mu
    upper_values = Dict(t => 0 for t in input.timesteps)
    println("algorithm started")
    outer_counter = 0
    while true
        println("Outer Loop: $(outer_counter)")
        outer_counter += 1
        inner_counter = 0
        total_obj = Inf64
        while true
            println("Inner Loop: $(inner_counter)")
            inner_counter += 1
            update_primal_objective(input, mu, dual_vars, primal_model, primal_obj, upper_vars, upper_obj, changed_profile_process)
            optimize!(primal_model)
            new_upper_values = Dict(t => value(upper_vars["delta"][t]) for t in input.timesteps)
            update_dual_obj(input, dual_model, new_upper_values, dual_vars, changed_profile_process)
            optimize!(dual_model)
            new_total_obj = objective_value(primal_model)


            println("total obj: $(objective_value(primal_model))")
            println("primal obj: $(value(primal_obj))")
            # test_primal(input, input_without_profile, changed_profile_process, new_upper_values)
            dual_obj = objective_function(dual_model)
            println("dual obj: $(value(dual_obj))")
            println("upper obj: $(value(upper_obj))")
            println(maximum(values(Dict(t => abs(new_upper_values[t] - upper_values[t]) for t in input.timesteps))))
            if maximum(values(Dict(t => abs(new_upper_values[t] - upper_values[t]) for t in input.timesteps))) < setting.min_stationary_change || abs(new_total_obj - total_obj) < setting.min_obj_improvement_rate || inner_counter > setting.max_inner_iterations
                break
            else
                upper_values = new_upper_values
                total_obj = new_total_obj
            end
        end
        if abs(value(primal_obj) - value(dual_obj)) < setting.duality_gap_tolerance || outer_counter > setting.max_outer_iterations
            break
        else
            mu *= 2
        end
    end
    println("primal obj: $(value(primal_obj))")
    println("dual obj: $(value(dual_obj))")
    println("upper obj: $(value(upper_obj))")
    changed_output = CESM.Model.get_output(input, primal_vars)
    return (upper_values, output, changed_output)
end

end