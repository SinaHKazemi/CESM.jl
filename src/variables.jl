module Variables

    export variables

    # set options are: :cp, :co, :year, :time, :region

    variables = Dict(
        "var_total_expenditure" => (type="Float", sets=(), default=0, dimension=:Money),
        "var_capital_expenditure" => (type="Float", sets=(), default=0, dimension=:Money),
        "var_operational_cost" => (type="Float", sets=(), default=0, dimension=:Money),
        "var_total_residual_value" => (type="Float", sets=(), default=0, dimension=:Money),
        "var_residual_value" => (type="Float", sets=(:cp,:year), default=0, dimension=:Money),
        "var_annual_emission" => (type="Float", sets=(:year,), default=Inf, dimension=:Money),
        "var_new_capacity" => (type="Float", sets=(:cp,:year), default=0, dimension=:Money),
        "var_active_capacity" => (type="Float", sets=(:cp,:year)),
        "var_legacy_capacity" => (type="Float", sets=(:cp,:year)),
        "var_power_in" => (type="Float", sets=(:cp,:year,:time)),
        "var_power_out" => (type="Float", sets=(:cp,:year,:time)),
        "var_total_energy_out" => (type="Float", sets=(:cp,:year)),
        "var_total_energy_in" => (type="Float", sets=(:cp,:year)),
        "var_energy_out_time" => (type="Float", sets=(:cp,:year,:time)),
        "var_energy_in_time" => (type="Float", sets=(:cp,:year,:time)),
        "var_net_energy_generation" => (type="Float", sets=(:co,:year,:time)),
        "var_net_energy_consumption" => (type="Float", sets=(:co,:year,:time)),
        "var_storage_level" => (type="Float", sets=(:cp,:year,:time)),
        "var_max_storage_level" => (type="Float", sets=(:cp,:year))
    )

end
