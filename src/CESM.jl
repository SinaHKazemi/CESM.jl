module CESM

include("variables.jl")
include("components.jl")
include("parser.jl")
include("model.jl")
include("visualization.jl")

# using relative imports inside the project
using .Variables
using .Model
using .Components
using .Parser
using .Visualization

# export whatever you want to make public
# export Variables, Model, Components, Parser, Visualization

end # module CESM
