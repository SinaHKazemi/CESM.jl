

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


dual_model = dualize(model,Gurobi.Optimizer)
# set_attribute(dual_model, "Method", 1)
CESM.Model.build_model(input,dual_model)
# model = JuMP.Model(dual_optimizer(Gurobi.Optimizer))
optimize!(dual_model)