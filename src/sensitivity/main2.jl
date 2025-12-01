
# PALM algorithm
using JuMP, Dualization, Gurobi
using Logging, LoggingExtras
using SHA

include("../core/CESM.jl")
using .CESM


struct Setting
    config_file::String
    manipulation_bound::Float64, # 0.1
    manipulated_cp::String, # "Battery"
    target_cp::String, # "PP_Wind" it has to be a renwewable
    target_change::Float64, # 0.2
    init_mu::Float64, # 1.0
    init_trust_region_radius::Float64, # 0.05
    min_stationary_change::Float64, # 1e-4
    min_obj_improvement_rate::Float64, # 1e-2
    last_year::Int64 # 2050
end


function logfile_name(s::Setting)
    data = sprint(io -> show(io, s))
    h = bytes2hex(sha1(data))[1:10]  # shortened hash
    return "log_$(s.manipulated_cp)_$(s.target_cp)_$(h).txt"
end

io = open(logfile_name(setting), "a")
file_logger = SimpleLogger(io, Logging.Info)
global_logger(file_logger)

setting = Setting(
    config_file = "config_sensitivity.yaml",
    manipulation_bound = 0.1,
    manipulated_cp = "Battery",
    target_cp = "PP_Wind",
    target_change = 0.2,
    init_mu = 1.0,
    init_trust_region_radius = 0.05,
    min_stationary_change = 1e-4,
    min_obj_improvement_rate = 1e-2,
    last_year = 2050
)

function start()
    input = CESM.Parser.parse_input(setting.config_file);
    timesteps = input.timesteps
    years = input.years
    (model,vars,constraints) = CESM.Model.build_model(input)
    CESM.Model.optimize_model(model)    
    @info "Initial optimization completed."
    @info "Objective value:  $(objective_value(model))"
    output = CESM.Model.get_output(input, vars)
    target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
    target_cp_capacity = sum(get(output["new_capacity"],(target_cp,y),0) for y in years if Int(y)<=setting.last_year)
    @info "$(setting.target_cp) capacity: $(target_cp_capacity)"
    manipulated_cp = first(filter(p -> p.name == setting.manipulated_cp, input.processes))


    dual_model = dualize(model,Gurobi.Optimizer; dual_names = DualNames("dual_var_", "dual_con_"))
    dual_obj = objective_function(dual_model)
    (model,vars,constrs) = CESM.Model.build_model(input,dual_model)
    primal_obj = objective_function(model)

    # set the solver to dual simplex
    set_attribute(model, "Method", 1) # https://docs.gurobi.com/projects/optimizer/en/current/reference/parameters.html#method

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
    vars["dual"] = Dict(index_tuple => variable_by_name(model, "dual_var_renewable_availability_$(setting.manipulated_cp)_$(index_tuple[1])_$(index_tuple[2])") for index_tuple in Iterators.product(years,timesteps)) 

    trust_region_radius_param = @variable(model, base_name= "trust_region_radius", set = Parameter(0.0))

    constrs["upper_delta"] = Dict()
    for t in timesteps
        constrs["upper_delta"][t] = @constraint(model, vars["delta"][t] == vars["ddelta"][t] , base_name="delta_ddelta_$(t)")
    end
    function change_upper_constraints(delta_values)
        for t in timesteps
            set_normalized_rhs(constrs["upper_delta"][t], delta_values[t])
        end
    end

    for t in timesteps
        @constraint(model, vars["delta"][t] >= -setting.manipulation_bound, base_name="delta_lowerbound_$(t)")
        @constraint(model, vars["delta"][t] <= setting.manipulation_bound, base_name="delta_upperbound_$(t)")
        @constraint(model, get_param("availability_profile",(manipulated_cp,t)) * (1 + vars["delta"][t]) <= 1, base_name="delta_upperbound_one_$(t)")
        @constraint(model, 1 + vars["delta"][t] >= 0, base_name="delta_lowerbound_zero_$(t)")
        @constraint(model, vars["abs_delta"][t] >= vars["delta"][t], base_name="abs_delta_lowerbound_$(t)")
        @constraint(model, vars["abs_delta"][t] >= -vars["delta"][t], base_name="abs_delta_upperbound_$(t)")
        @constraint(model, vars["abs_delta"][t] >= 0, base_name="abs_delta_zero_bound_$(t)")
        @constraint(model, vars["ddelta"][t] <= trust_region_radius_param, base_name="ddelta_upperbound_$(t)")
        @constraint(model, -vars["ddelta"][t] <= trust_region_radius_param, base_name="ddelta_lowerbound_$(t)")
    end

    @constraint(model, sum(vars["delta"][t]* get_param("availability_profile",(manipulated_cp,t)) for t in timesteps) == 0, base_name="zero_sum")

    MU = setting.initial_mu

    @objective(model, Min, sum(vars["abs_delta"][t] for t in timesteps) + MU * (primal_obj-dual_obj))
    @constraint(model, sum(vars["new_capacity"][target_cp,y] for y in years if Int(y)<=setting.last_year) >= target_cp_capacity * (1+setting.target_change), base_name="$(target_cp)_change")

    function change_dual_constraints(delta_values, dual_values)
        for y in years
            con = constraint_by_name(model, "dual_con_active_capacity_$(setting.manipulated_cp)_$(y)")
            for t in timesteps
                coeff = get_param("availability_profile",(manipulated_cp,t))
                set_normalized_coefficient(con, vars["dual"][y,t], (1 + delta_values[t]) * coeff)
                set_normalized_coefficient(con, vars["ddelta"][t], dual_values[(y,t)] * coeff)
            end
        end
    end

    function change_primal_constraints(delta_values, cap_values)
        for y in years
            for t in timesteps
                coeff = get_param("availability_profile",(manipulated_cp,t))
                set_normalized_coefficient(constrs["renewable_availability"][manipulated_cp,y,t], vars["active_capacity"][manipulated_cp,y], - (1 + delta_values[t]) * coeff)
                set_normalized_coefficient(constrs["renewable_availability"][manipulated_cp,y,t], vars["ddelta"][t], - cap_values[y] * coeff)
            end
        end
    end

    # fix variables at zero
    for t in timesteps
        fix(vars["delta"][t], 0.0)
        fix(vars["ddelta"][t], 0.0)
        fix(vars["abs_delta"][t], 0.0)
    end

    optimize!(model)
    # println(sum(value(vars["new_capacity"][target_cp,y]) for y in years))
    # println("primal obj after fixing: ", value(primal_obj))
    # println("dual obj after fixing: ", value(dual_obj))

    dual_values = Dict((y,t) => value(vars["dual"][y,t]) for y in years, t in timesteps)
    cap_values = Dict(y => value(vars["active_capacity"][manipulated_cp,y]) for y in years)
    delta_values = Dict(t => 0.0 for t in timesteps)

    change_dual_constraints(delta_values, dual_values)
    change_primal_constraints(delta_values, cap_values)
    change_upper_constraints(delta_values)

    for t in timesteps
        unfix(vars["delta"][t])
        unfix(vars["ddelta"][t])
        unfix(vars["abs_delta"][t])
    end
    
    obj_value = Inf64
    trust_region_radius = setting.init_trust_region_radius
    set_parameter_value(trust_region_radius_param, trust_region_radius)

    total_inner_counter = 0
    outer_counter = 0
    while true
        outer_counter += 1
        println("Outer Iteration: ", outer_counter)
        inner_counter = 0
        while true
            inner_counter += 1
            total_inner_counter += 1
            
            @info "Inner Iteration:  $(inner_counter)"            
            
            change_upper_constraints(delta_values)
            change_dual_constraints(delta_values, dual_values)
            change_primal_constraints(delta_values, cap_values)
            
            # unfix the upper-level variables
            for t in timesteps             
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

            @info "termination_status:  $(termination_status(model))"
            # println("Sum delta values: ", sum(value(vars["delta"][t])* get_param("availability_profile",(manipulated_cp,t)) for t in timesteps))
            if maximum([abs(value(vars["ddelta"][t])) for t in timesteps]) < setting.min_stationary_change
                @info "Inner loop converged"
                break
            end
            new_delta_values = Dict(t => value(vars["delta"][t]) for t in timesteps)
            # ddelta_values = Dict(t => value(vars["ddelta"][t]) for t in timesteps)
            # println("New delta values: ", maximum(abs.(values(ddelta_values))))


            # fix the upper-level variables
            change_upper_constraints(new_delta_values)
            change_dual_constraints(new_delta_values, dual_values)
            change_primal_constraints(new_delta_values, cap_values)
            
            for t in timesteps
                # no need to fix delta and abs_delta
                fix(vars["ddelta"][t], 0)
            end
        
            set_attribute(model, "DualReductions", 0)
            optimize!(model)
            @info "termination_status:  $(termination_status(model))"

            # check for feasibility
            if termination_status(model) == MOI.INFEASIBLE_OR_UNBOUNDED || termination_status(model) == MOI.INFEASIBLE
                @info "Infeasible solution."
                trust_region_radius /= 2
                set_parameter_value(trust_region_radius_param, trust_region_radius)
                continue
            else
                @info "Feasible solution."
                @info "primal obj after fixing: $(value(primal_obj))"
                @info "dual obj after fixing: $(value(dual_obj))"
                @info "Change in objective value: $(obj_value - objective_value(model))"
                @info "Sum of delta: $(sum(abs(new_delta_values[t]-delta_values[t]) for t in timesteps))"
                if (obj_value - objective_value(model)) / maximum(abs(value(vars["ddelta"][t])) for t in timesteps) < setting.min_obj_improvement_rate
                    @info "Objective improvement rate is below the threshold."
                    trust_region_radius /= 2
                    set_parameter_value(trust_region_radius_param, trust_region_radius)
                    continue
                end

                obj_value = objective_value(model)
                
                # adjust delta values or other parameters as needed
                dual_values = Dict((y,t) => value(vars["dual"][y,t]) for y in years, t in timesteps)
                cap_values = Dict(y => value(vars["active_capacity"][PP_Wind,y]) for y in years)
                delta_values = new_delta_values

                trust_region_radius = min(trust_region_radius * 2, setting.init_trust_region_radius)
                set_parameter_value(trust_region_radius_param, trust_region_radius)
            end
        end
        if value(primal_obj) - value(dual_obj) < 1e-2
            println("Converged in outer loop")
            break
        end
        
        MU *= 2
        trust_region_radius = setting.init_trust_region_radius
        set_parameter_value(trust_region_radius_param, trust_region_radius)
        @objective(model, Min, sum(vars["abs_delta"][t] for t in timesteps) + MU * (primal_obj-dual_obj))
        obj_value = Inf64
    end
end

start()