module MGA

include("core.jl")
include("functions.jl")
include("min_max.jl")
include("analysis.jl")

using .MGACore
using .MGAFunctions
using .MinMaxMGA
using .MGAAnalysis

export solve_optimal, add_slack_constraint
export MGA_OBJECTIVE_DEFS
export run_min_max_mga, analyze_mga_results

end
