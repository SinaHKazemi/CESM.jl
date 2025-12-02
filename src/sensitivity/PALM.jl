
module PALM
# PALM algorithm
using JuMP, Dualization, Gurobi
using Logging, LoggingExtras
using SHA

include("../core/CESM.jl")
using .CESM

export Setting, run_PALM, logfile_name

function pretty_print(io::IO, x)
    T = typeof(x)
    fields = fieldnames(T)
    values = [getfield(x, f) for f in fields]

    # Determine column width for alignment
    maxlen = maximum(length.(String.(fields)))

    println(io, "=== $(T) ===")
    for (f, v) in zip(fields, values)
        fname = String(f)
        padding = " " ^ (maxlen - length(fname))
        println(io, fname, padding, " : ", v)
    end
end

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

function Base.show(io::IO, s::Setting)
    pretty_print(io, s)
end

function Setting(; 
        config_file::String,
        manipulation_bound::Float64,
        manipulated_cp::String,
        target_cp::String,
        target_change::Float64,
        init_mu::Float64,
        init_trust_region_radius::Float64=0.05,
        min_stationary_change::Float64=1e-4,
        min_obj_improvement_rate::Float64=1e-2,
        last_year::Int64=typemax(Int),
        duality_gap_tolerance::Float64=1e-2,
        max_outer_iterations::Int64=40,
        max_inner_iterations::Int64=50,
        log_folder_path::String="."
    )
    
    if manipulation_bound < 0.0 || manipulation_bound > 1.0
        throw(ArgumentError("manipulation_bound must be between 0 and 1, got $manipulation_bound"))
    end

    return Setting(
        config_file,
        manipulation_bound,
        manipulated_cp,
        target_cp,
        target_change,
        init_mu,
        init_trust_region_radius,
        min_stationary_change,
        min_obj_improvement_rate,
        last_year,
        duality_gap_tolerance,
        max_outer_iterations,
        max_inner_iterations,
        log_folder_path
    )
end

function logfile_name(s::Setting)
    data = sprint(io -> show(io, s))
    h = bytes2hex(sha1(data))[1:10]  # shortened hash
    return "log_$(s.manipulated_cp)_$(s.target_cp)_$(h)"
end

function simple_file_logger(path::String)
    io = open(path, "w")
    return FormatLogger(io) do io, log
        # Print only: "Info: message"
        println(io, "$(log.level): ", log.message)

        # flush so logs appear immediately
        flush(io)
    end
end


function run_PALM(setting::Setting)

    file_logger = simple_file_logger(joinpath(setting.log_folder_path, logfile_name(setting) * ".txt"))
    global_logger(file_logger)
    @info "Starting PALM algorithm with settings: $(setting)"

    input = CESM.Parser.parse_input(setting.config_file);

    function get_param(param_name, keys)
        return CESM.Model.get_parameter(input, param_name, keys)
    end

    timesteps = input.timesteps
    years = input.years
    (model,vars,constraints) = CESM.Model.build_model(input)
    set_attribute(model, "OutputFlag", 0)
    CESM.Model.optimize_model(model)
    @info "Initial optimization completed."
    @info "Objective value:  $(objective_value(model))"
    output = CESM.Model.get_output(input, vars)
    
    target_cp = nothing
    try
        target_cp = first(filter(p -> p.name == setting.target_cp, input.processes))
    catch e
        @error "Could not find target_cp: $(setting.target_cp) in processes."
    end

    manipulated_cp = nothing
    try
        manipulated_cp = first(filter(p -> p.name == setting.manipulated_cp, input.processes))
    catch e
        @error "Could not find manipulated_cp: $(setting.manipulated_cp) in processes."
    end

    target_cp_capacity = sum(get(output["new_capacity"],(target_cp,y),0) for y in years if Int(y)<=setting.last_year)
    @info "$(setting.target_cp) capacity: $(target_cp_capacity)"
    
    dual_model = dualize(model,Gurobi.Optimizer; dual_names = DualNames("dual_var_", "dual_con_"))
    dual_obj = objective_function(dual_model)
    (model,vars,constrs) = CESM.Model.build_model(input,dual_model)
    primal_obj = objective_function(model)

    # set the solver to dual simplex
    set_attribute(model, "Method", 1) # https://docs.gurobi.com/projects/optimizer/en/current/reference/parameters.html#method
    set_attribute(model, "OutputFlag", 0)



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

    MU = setting.init_mu

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
        if outer_counter > setting.max_outer_iterations
            @info "Reached maximum number of outer iterations."
            break
        end
        @info "Outer Iteration: $(outer_counter)"

        inner_counter = 0
        while true
            inner_counter += 1
            if inner_counter > setting.max_inner_iterations
                @info "Reached maximum number of inner iterations."
                break
            end
            total_inner_counter += 1
            
            @info "Inner Iteration:  $(inner_counter)"
            @info "Total Inner Iterations:  $(total_inner_counter)"          
            
            change_upper_constraints(delta_values)
            change_dual_constraints(delta_values, dual_values)
            change_primal_constraints(delta_values, cap_values)
            
            # unfix the upper-level variables
            for t in timesteps
                if is_fixed(vars["ddelta"][t])
                    unfix(vars["ddelta"][t])
                end
            end

            optimize!(model)
            @info "termination_status (find delta):  $(termination_status(model))"
            if maximum([abs(value(vars["ddelta"][t])) for t in timesteps]) < setting.min_stationary_change
                @info "Inner loop converged"
                break
            end
            new_delta_values = Dict(t => value(vars["delta"][t]) for t in timesteps)

            # fix the upper-level variables
            change_upper_constraints(new_delta_values)
            change_dual_constraints(new_delta_values, dual_values)
            change_primal_constraints(new_delta_values, cap_values)
            
            for t in timesteps
                # no need to fix delta and abs_delta
                fix(vars["ddelta"][t], 0)
            end
        
            # to distinguish between infeasible and unbounded
            # set_attribute(model, "DualReductions", 0)
            optimize!(model)
            @info "termination_status (find feasible primal and dual):  $(termination_status(model))"

            # check for feasibility
            if termination_status(model) == MOI.INFEASIBLE_OR_UNBOUNDED || termination_status(model) == MOI.INFEASIBLE
                @info "Infeasible Solution."
                trust_region_radius /= 2
                set_parameter_value(trust_region_radius_param, trust_region_radius)
                continue
            else
                @info "Feasible Solution."
                @info "primal obj: $(value(primal_obj))"
                @info "dual obj: $(value(dual_obj))"
                @info "duality gap: $(value(primal_obj) - value(dual_obj))"
                @info "obj value improvement: $(obj_value - objective_value(model))"
                @info "sum of delta: $(sum(abs(new_delta_values[t]) for t in timesteps))"
                if (obj_value - objective_value(model)) / maximum(abs(value(vars["ddelta"][t])) for t in timesteps) < setting.min_obj_improvement_rate
                    @info "Objective improvement rate is below the threshold."
                    trust_region_radius /= 2
                    set_parameter_value(trust_region_radius_param, trust_region_radius)
                    continue
                end

                obj_value = objective_value(model)
                
                # adjust delta values or other parameters as needed
                dual_values = Dict((y,t) => value(vars["dual"][y,t]) for y in years, t in timesteps)
                cap_values = Dict(y => value(vars["active_capacity"][manipulated_cp,y]) for y in years)
                delta_values = new_delta_values

                trust_region_radius = min(trust_region_radius * 2, setting.init_trust_region_radius)
                set_parameter_value(trust_region_radius_param, trust_region_radius)
            end
        end
        if value(primal_obj) - value(dual_obj) < 1e-2
            @info "Converged in outer loop"
            return (delta_values)
            break
        end
        
        MU *= 2
        trust_region_radius = setting.init_trust_region_radius
        set_parameter_value(trust_region_radius_param, trust_region_radius)
        @objective(model, Min, sum(vars["abs_delta"][t] for t in timesteps) + MU * (primal_obj-dual_obj))
        obj_value = Inf64
    end
end

    
end

