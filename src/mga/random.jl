module RandomMGA

using ..Volume
using CESM.Model
using CESM.Components

function random_vector(folder_path)
    volumes::Vector{Float64} = []
    outputs::Vector{Output} = []
    while length(volumes) < 2 || (volumes[end] - volumes[end-1])/volumes[end-1] > threshold
        obj_vector = generate_random(20)
        set_objective(model, obj_vector)
        optimize!(model)
        fix_planning_variables(model)
        set_main_objective(model)
        optimize!(model)
        output = get_output(model)
        push!(outputs, output)
        volume = calculate_volume(outputs)
        push!(volumes, volume)
        serialize("output$(length(outputs)).jls", input)
    end
end

function generate_random(dim:Int)
end

function set_objective()
end

function fix_planning_variables()
end

function set_main_objective()
end

end

