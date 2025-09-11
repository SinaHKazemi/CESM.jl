module Variables

    export variables
    
    variables = Dict(
        "total_cost" => (type="Float", sets=(), unit="money"),
        "capital_cost" => (type="Float", sets=(), unit="money"),
        "operational_cost" => (type="Float", sets=(), unit="money"),
        "total_residual_value" => (type="Float", sets=(), unit="money"),
        "residual_value" => (type="Float", sets=("P", "Y"), unit="money"),
        "annual_emission" => (type="Float", sets=("Y",), unit="CO2 Emissions"),
        "new_capacity" => (type="Float", sets=("P", "Y"), unit="money"),
        "active_capacity" => (type="Float", sets=("P", "Y"), unit="power"),
        "legacy_capacity" => (type="Float", sets=("P", "Y"), unit="power"),
        "power_in" => (type="Float", sets=("P", "Y", "T"), unit="power"),
        "power_out" => (type="Float", sets=("P", "Y", "T"), unit="power"),
        "total_energy_out" => (type="Float", sets=("P", "Y"), unit="energy"),
        "total_energy_in" => (type="Float", sets=("P", "Y"), unit="energy"),
        "energy_out_time" => (type="Float", sets=("P", "Y", "T"), unit="energy"),
        "energy_in_time" => (type="Float", sets=("P", "Y", "T"), unit="energy"),
        "net_energy_generation" => (type="Float", sets=("C", "Y", "T"), unit="energy"),
        "net_energy_consumption" => (type="Float", sets=("C", "Y", "T"), unit="energy"),
        "storage_level" => (type="Float", sets=("P", "Y", "T"), unit="energy"),
        "max_storage_level" => (type="Float", sets=("P", "Y"), unit="energy")
    )

end
