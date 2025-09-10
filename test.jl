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

# println("Conversion complete: '$input_file' -> '$output_file'")

include("./src/CESM.jl")
using .CESM

# include("src/parser.jl")
# include("src/components.jl")
# include("src/model.jl")
# using CESM.Parse
# using .Components
input = CESM.Parse.parse_input("./examples/Germany/GETM.json");