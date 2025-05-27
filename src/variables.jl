module Variables

    export variables

    variables = Dict(
        "total_cost" => (type="Float", sets=(), quantity="Money"),
        "capital_cost" => (type="Float", sets=(), quantity="Money"),
        "operational_cost" => (type="Float", sets=(), quantity="Money"),
        "total_residual_value" => (type="Float", sets=(), quantity="Money"),
        "residual_value" => (type="Float", sets=("P", "Y"), quantity="Money"),
        "annual_emission" => (type="Float", sets=("Y",), quantity="CO2 Emissions"),
        "new_capacity" => (type="Float", sets=("P", "Y"), quantity=Money),
        "active_capacity" => (type="Float", sets=("P", "Y")),
        "legacy_capacity" => (type="Float", sets=("P", "Y")),
        "power_in" => (type="Float", sets=("P", "Y", "T")),
        "power_out" => (type="Float", sets=("P", "Y", "T")),
        "total_energy_out" => (type="Float", sets=("P", "Y")),
        "total_energy_in" => (type="Float", sets=("P", "Y")),
        "energy_out_time" => (type="Float", sets=("P", "Y", "T")),
        "energy_in_time" => (type="Float", sets=("P", "Y", "T")),
        "net_energy_generation" => (type="Float", sets=("C", "Y", "T")),
        "net_energy_consumption" => (type="Float", sets=("C", "Y", "T")),
        "storage_level" => (type="Float", sets=("P", "Y", "T")),
        "max_storage_level" => (type="Float", sets=("P", "Y"))
    )

end
