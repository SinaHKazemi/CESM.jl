# 1. Include the necessary modules
include("./src/core/CESM.jl")
include("./src/mga/MGA.jl")
using PrettyTables

# 2. Exploration Parameters
config_path = "./examples/House/config.json"
output_dir = "results/mga_house"
epsilon = 0.05

println("--- Starting MGA Min/Max Exploration ---")
println("Model: House")
println("Slack (epsilon): $(epsilon * 100)%")
println("Output Directory: $output_dir")

# 3. Parse the House input
input = CESM.Parser.parse_input(config_path)

# 4. Run the Min/Max method
# This function handles: solve optimal -> add slack constraint -> min/max all objectives
MGA.run_min_max_mga(input; epsilon=epsilon, output_dir=output_dir)

println("--- MGA Exploration Complete ---")

println("\n--- Analyzing Results ---")
results_summary = MGA.analyze_mga_results(input, output_dir)

# 6. Print a summary table using PrettyTables
case_names = sort(collect(keys(results_summary)))
metric_names = sort(collect(keys(MGA.MGA_OBJECTIVE_DEFS)))

# Construct data matrix: rows are cases, columns are metrics
data = [round(results_summary[c][m], digits=2) for c in case_names, m in metric_names]

# Print the table
# We use column_labels as seen in your documentation example
pretty_table(
    data; 
    column_labels = metric_names,
    row_labels    = case_names,
    alignment     = :c,
    hlines        = :all,
    crop          = :none
)

println("\nYou can find the .jls results in the '$output_dir' folder.")
