module MGACore

using JuMP
using ...CESM.Model
using ...CESM.Components

export solve_optimal, add_slack_constraint

"""
    solve_optimal(input::Input)

Solves the base optimization problem to optimality.
Returns (model, vars, constraints).
"""
function solve_optimal(input::Input)
    model, vars, constraints = build_model(input)
    optimize_model(model)
    return model, vars, constraints
end

"""
    add_slack_constraint(model, vars, epsilon)

Adds a constraint to the model ensuring the objective value stays within 
a certain `epsilon` threshold of the optimal solution.
"""
function add_slack_constraint(model, vars, epsilon)
    f_star = objective_value(model)
    # The objective is vars["total_cost"] as per set_obj! in model.jl
    @constraint(model, slack_constraint, vars["total_cost"] <= (1 + epsilon) * f_star)
    return f_star
end

end
