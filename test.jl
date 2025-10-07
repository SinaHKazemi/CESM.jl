# # Get the directory where the script resides
# script_dir = "./examples/Germany/time_series/"

# # Build full file paths
# input_file = joinpath(script_dir, "Solar_production_mean.txt")
# output_file = joinpath(script_dir, "PV_Availability_mean.txt")


# # Open the input file, read content, and split by spaces
# data = read(input_file, String)
# tokens = split(data)  # by default, split on any whitespace

# # Write each token to a new line in the output file
# open(output_file, "w") do io
#     for token in tokens
#         println(io, token)
#     end
# end

# using JuMP, Gurobi
# model = read_from_file("model.lp")
# set_optimizer(model, Gurobi.Optimizer)
# optimize!(model)

# println("Conversion complete: '$input_file' -> '$output_file'")


include("./src/CESM.jl")
using .CESM
input = CESM.Parser.parse_input("./examples/Germany/GETM.json");
CESM.Model.run_model(input)

# using CairoMakie

# tbl = (cat = [100, 100, 100, 200, 200, 200, 300, 300, 300], # column 
#        height = 0.1:0.1:0.9, # values
#        grp = [4, 5, 6, 4, 5, 6, 4, 5, 6], # 
#        grp1 = [1, 2, 2, 1, 1, 2, 1, 1, 2],
#        grp2 = [1, 1, 2, 1, 2, 1, 1, 2, 1],
#        grp3 = ["mediumorchid3", "goldenrod1", "seashell","goldenrod1", "aqua", "seagreen2","seashell", "aqua", "mediumorchid3"]
#        )

# barplot(tbl.cat, tbl.height,
#         stack = tbl.grp, # group
#         color = tbl.grp3,
#         axis = (xticks = ([100,200,300], ["left", "middle", "right"]),
#                 title = "Stacked bars"),
#         )

# using Serialization

# # Save (serialize) any Julia object
# serialize("output.jls", my_data)

# # Load it back
# data = deserialize("output.jls")