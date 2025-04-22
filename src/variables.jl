module Variables

    export variables

    variables = Dict(
        :TOTEX => (type="Float", sets=(), default=0, dimension=:Money),
        :CAPEX => (type="Float", sets=(), default=0, dimension=:Money),
        :OPEX => (type="Float", sets=(), default=0, dimension=:Money),
        :TotalSalvage => (type="Float", sets=(), default=0, dimension=:Money),
        :Salvage => (type="Float", sets=(:CP,:Y), default=0, dimension=:Money),
        :AnnualEmission => (type="Float", sets=(:Y,), default=Inf, dimension=:Money),
        :CapNew => (type="Float", sets=(:CP,:Y), default=0, dimension=:Money),
        :CapActive => (type="Float", sets=(:CP,:Y)),
        :CapRes => (type="Float", sets=(:CP,:Y)),
        :PowerIn => (type="Float", sets=(:CP,:Y,:T)),
        :PowerOut => (type="Float", sets=(:CP,:Y,:T)),
        :EnergyOutTot => (type="Float", sets=(:CP,:Y)),
        :EnergyInTot => (type="Float", sets=(:CP,:Y)),
        :EnergyOutTime => (type="Float", sets=(:CP,:Y,:T)),
        :EnergyInTime => (type="Float", sets=(:CP,:Y,:T)),
        :EnergyNetGen => (type="Float", sets=(:CO,:Y,:T)),
        :EnergyNetCon => (type="Float", sets=(:CO,:Y,:T)),
        :StorageLevel => (type="Float", sets=(:CP,:Y,:T)),
        :StorageLevelMax => (type="Float", sets=(:CP,:Y))
    )

end
# input = Dict(
#     "sets" => Dict(
#         "Y" => Vector{Int}(),
#         "CO" => Vector{String},
#         "TSS" => Vector{Int}(),
#         "CP" => Vector{Strings},
#     ),
#     "params" => Dict(),
#     "plots" => Dict(
#         "CP" => Dict(),
#         "CO" => Dict()
#     )
# )
