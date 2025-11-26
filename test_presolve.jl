using JuMP, HiGHS, Gurobi

model = JuMP.Model(HiGHS.Optimizer)
model = read_from_file("model.mps")

optimize!(model)