

include("../core/CESM.jl")
using .CESM
input = CESM.Parser.parse_input("./examples/House/config.json");
(model,vars,constraints) = CESM.Model.build_model(input)
# using Serialization
# serialize("output.jls", output)
# serialize("input.jls", input)
# output = deserialize("output.jls")
# input = deserialize("input.jls")



using JuMP, Dualization, Gurobi

PP_Wind = first(filter(p -> p.name == "PP_Wind", input.processes))
Battery = first(filter(p -> p.name == "Battery", input.processes))


dual_model = dualize(model,Gurobi.Optimizer; dual_names = DualNames("dual_var_", "dual_con_"))
dual_obj = objective_function(dual_model)
(model,vars,constrs) = CESM.Model.build_model(input,dual_model)
primal_obj = objective_function(model)

@constraint(model, dual_obj == primal_obj, base_name="strong_duality")

@objective(model, Max, sum(vars["new_capacity"][Battery,y] for y in input.years))

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


vars["delta"] = Dict(index => @variable(model, base_name= "delta" * "_" * string(index)) for index in input.timesteps)

for t in input.timesteps
    @constraint(model, vars["delta"][t] >= -0.1, base_name="delta_lowerbound_$(t)")
    @constraint(model, vars["delta"][t] <= 0.1, base_name="delta_upperbound_$(t)")
end

@constraint(model, sum(vars["delta"][t]* get_param("availability_profile",(PP_Wind,t)) for t in input.timesteps) == 0, base_name="zero_sum")


for p in input.processes
    (p != PP_Wind) && continue
    for y in input.years
        for t in input.timesteps
            delete(model, constrs["renewable_availability"][p,y,t])
            constrs["renewable_availability"][p,y,t] = @constraint(
                model,
                vars["power_out"][p,y,t] <= vars["active_capacity"][p,y] * (1 + vars["delta"][t]) * get_param("availability_profile",(p,t)),
                base_name = "renewable_availability_$(p)_$(y)_$(t)"
            )
        end
    end
end

for p in input.processes
    (p != PP_Wind) && continue
    for y in input.years
        con = constraint_by_name(model, "dual_con_active_capacity_$(p)_$(y)")
        f = JuMP.constraint_object(con).func + sum(variable_by_name(model, "dual_var_renewable_availability_$(p)_$(y)_$(t)") * vars["delta"][t] * get_param("availability_profile",(p,t)) for t in input.timesteps)
        delete(model, con)
        @constraint(model, f>=0, base_name="dual_con_active_capacity_$(p)_$(y)")
    end
end


function my_callback(cb_data, cb_where)
    status = callback_node_status(cb_data, model)
    if status == MOI.CALLBACK_NODE_STATUS_INTEGER
        Gurobi.
        obj_val = callback_objective_value(cb_data)
        println("obj=$(obj_val)")
    end
end

set_attribute(model, Gurobi.CallbackFunction(), my_callback)

optimize!(model)