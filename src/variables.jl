module Variables

    export variables

    variables = Dict(
        :TOTEX => (type="Float", sets=(), default=0, dimension=:Money),
        :CAPEX => (type="Float", sets=(), default=0, dimension=:Money),
        :OPEX => (type="Float", sets=(), default=0, dimension=:Money),
        :TotalSalvage => (type="Float", sets=(), default=0, dimension=:Money),
        :Salvage => (type="Float", sets=(:cp,:year), default=0, dimension=:Money),
        :AnnualEmission => (type="Float", sets=(:year,), default=Inf, dimension=:Money),
        :CapNew => (type="Float", sets=(:cp,:year), default=0, dimension=:Money),
        :CapActive => (type="Float", sets=(:cp,:year)),
        :CapRes => (type="Float", sets=(:cp,:year)),
        :PowerIn => (type="Float", sets=(:cp,:year,:time)),
        :PowerOut => (type="Float", sets=(:cp,:year,:time)),
        :EnergyOutTot => (type="Float", sets=(:cp,:year)),
        :EnergyInTot => (type="Float", sets=(:cp,:year)),
        :EnergyOutTime => (type="Float", sets=(:cp,:year,:time)),
        :EnergyInTime => (type="Float", sets=(:cp,:year,:time)),
        :EnergyNetGen => (type="Float", sets=(:co,:year,:time)),
        :EnergyNetCon => (type="Float", sets=(:co,:year,:time)),
        :StorageLevel => (type="Float", sets=(:cp,:year,:time)),
        :StorageLevelMax => (type="Float", sets=(:cp,:year))
    )

end
