module MinMaxMGA

using JuMP
using Serialization
using ..MGACore
using ..MGAFunctions
using ...CESM.Model
using ...CESM.Components

export run_min_max_mga

"""
    run_min_max_mga(input::Input; epsilon::Float64, output_dir::String)

Performs the Min/Max MGA method:
1. Solves the model to find the optimal solution (f*).
2. Adds a constraint: total_cost <= (1 + epsilon) * f*.
3. Systematically minimizes and maximizes each MGA objective.
Serializes each resulting `Output` to `output_dir`.
"""
function run_min_max_mga(input::Input; epsilon::Float64, output_dir::String)
    # Create directory if it doesn't exist
    mkpath(output_dir)

    # 1. Solve optimal solution
    println("Solving for optimal solution...")
    model, vars, constraints = solve_optimal(input)
    @assert termination_status(model) == JuMP.MOI.OPTIMAL "Initial optimal solve did not find an optimal solution."
    
    # Save optimal solution if it doesn't exist
    opt_path = joinpath(output_dir, "optimal.jls")
    if !isfile(opt_path)
        serialize(opt_path, get_output(input, vars))
    end

    # 2. Add slack constraint
    println("Adding slack constraint with epsilon = $epsilon...")
    f_star = add_slack_constraint(model, vars, epsilon)
    
    # 3. Explore structural MGA objectives
    for (name, info) in MGA_OBJECTIVE_DEFS
        name == "total_cost" && continue 
        
        obj_expr = @expression(model, info.func(input, vars))
        println("Exploring: $(name)")

        for suffix in ["min", "max"]
            filename = "$(name)_$suffix.jls"
            filepath = joinpath(output_dir, filename)

            if isfile(filepath)
                println("  -> Skipping $(suffix)imization for $(name) (already exists)")
                continue
            end

            println("  -> $(uppercasefirst(suffix))imizing...")
            if suffix == "min"
                @objective(model, Min, obj_expr)
            else
                @objective(model, Max, obj_expr)
            end
            optimize!(model)
            @assert termination_status(model) == JuMP.MOI.OPTIMAL "Min/Max optimization for $(name) ($suffix) did not find an optimal solution."
            
            # Serialize result to disk
            serialize(filepath, get_output(input, vars))
        end
    end
    
    println("MGA exploration complete. Results saved in: $output_dir")
    return nothing
end

end
