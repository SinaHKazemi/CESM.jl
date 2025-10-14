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
# model = read_from_file("model.mps")
# set_optimizer(model, Gurobi.Optimizer)
# optimize!(model)

# println("Conversion complete: '$input_file' -> '$output_file'")


include("./src/core/CESM.jl")
using .CESM
# input = CESM.Parser.parse_input("./examples/House/config.json");
# output = CESM.Model.run_model(input)
# using Serialization
# serialize("output.jls", output)
# serialize("input.jls", input)
output = deserialize("output.jls")
input = deserialize("input.jls")


# CESM.Visualization.plot_P_Y(input,output,"new_capacity", carrier_out=CESM.Components.Carrier("Industrial_Heat_LT"))
# CESM.Visualization.plot_P_Y(input,output,"new_capacity", carrier_out="Electricity")
# CESM.Visualization.plot_P_Y(input,output,"active_capacity", carrier_out="Electricity")
# CESM.Visualization.plot_P_Y(input,output,"total_energy_out", carrier_out="Electricity")
# CESM.Visualization.plot_Y(input,output,"annual_emission")
CESM.Visualization.plot_P_Y_T(input,output,"energy_out_time", 2030, carrier_out= "Electricity")
# CESM.Visualization.plot_scalar(input,output,["total_cost", "operational_cost", "capital_cost"])
# CESM.Visualization.plot_sankey(input,output,2050)

# using CairoMakie
# using WGLMakie
# WGLMakie.activate!()

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

# using SankeyMakie
# using GLMakie
# GLMakie.activate!()
# using Random

# connections = [
#     (1, 2, 1100),
#     (2, 4, 300),
#     (6, 2, 1400),
#     (2, 3, 500),
#     (2, 5, 300),
#     (5, 7, 100),
#     (2, 8, 100),
#     (3, 9, 150),
#     (2, 10, 500),
#     (10, 11, 50),
#     (10, 12, 80),
#     (5, 13, 150),
#     (3, 14, 100),
#     (10, 15, 300),
# ]

# labels = [
#     "Salary",
#     "Income",
#     "Rent",
#     "Insurance",
#     "Car",
#     "Salary 2",
#     "Depreciation",
#     "Internet",
#     "Electricity",
#     "Food & Household",
#     "Fast Food",
#     "Drinks",
#     "Gas",
#     "Water",
#     "Groceries",
# ]

# sankey(connections,
#     nodelabels = labels,
#     nodecolor = Makie.to_colormap(:tab20)[1:length(labels)],
#     linkcolor = SankeyMakie.Gradient(0.7),
#     axis = hidden_axis(),
#     figure = (; size = (1000, 500))
# )