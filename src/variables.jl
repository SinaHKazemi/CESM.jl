module Variables

    export variables

    # set options are: :cp, :co, :year, :time, :region

    variables = Dict(
        "var_total_cost" => (type="Float", sets=(), quantity="Money"),
        "var_capital_cost" => (type="Float", sets=(), quantity="Money"),
        "var_operational_cost" => (type="Float", sets=(), quantity="Money"),
        "var_total_residual_value" => (type="Float", sets=(), quantity="Money"),
        "var_residual_value" => (type="Float", sets=("P", "Y"), quantity="Money"),
        "var_annual_emission" => (type="Float", sets=("Y",), quantity="CO2 Emissions"),
        "var_new_capacity" => (type="Float", sets=("P", "Y"), quantity=Money),
        "var_active_capacity" => (type="Float", sets=("P", "Y")),
        "var_legacy_capacity" => (type="Float", sets=("P", "Y")),
        "var_power_in" => (type="Float", sets=("P", "Y", "T")),
        "var_power_out" => (type="Float", sets=("P", "Y", "T")),
        "var_total_energy_out" => (type="Float", sets=("P", "Y")),
        "var_total_energy_in" => (type="Float", sets=("P", "Y")),
        "var_energy_out_time" => (type="Float", sets=("P", "Y", "T")),
        "var_energy_in_time" => (type="Float", sets=("P", "Y", "T")),
        "var_net_energy_generation" => (type="Float", sets=("C", "Y", "T")),
        "var_net_energy_consumption" => (type="Float", sets=("C", "Y", "T")),
        "var_storage_level" => (type="Float", sets=("P", "Y", "T")),
        "var_max_storage_level" => (type="Float", sets=("P", "Y"))
    )

end
