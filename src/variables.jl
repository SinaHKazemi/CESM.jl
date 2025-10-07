module Variables

    export variables
    
    const ALLOWED_TYPES = Set(["Integer", "Float", "Boolean"])
    const ALLOWED_SETS  = Set(["Y", "T", "C", "P"])

    struct VariableDef
        type::String
        sets::Tuple
        unit::String
        function VariableDef(; type::String, sets::Tuple, unit::String)
            type ∈ ALLOWED_TYPES || error("Invalid type: $type. Must be one of $ALLOWED_TYPES")
            all(s -> s ∈ ALLOWED_SETS, sets) || error("Invalid sets: $sets. Each element must be one of $ALLOWED_SETS")
            return new(type, sets, unit)
        end
    end

    variables = Dict{String, VariableDef}(
        "total_cost"           => VariableDef(type="Float", sets=(), unit="money"),
        "capital_cost"         => VariableDef(type="Float", sets=(), unit="money"),
        "operational_cost"     => VariableDef(type="Float", sets=(), unit="money"),
        "total_residual_value" => VariableDef(type="Float", sets=(), unit="money"),
        "residual_value"       => VariableDef(type="Float", sets=("P", "Y"), unit="money"),
        "annual_emission"      => VariableDef(type="Float", sets=("Y",), unit="CO2 Emissions"),
        "new_capacity"         => VariableDef(type="Float", sets=("P", "Y"), unit="money"),
        "active_capacity"      => VariableDef(type="Float", sets=("P", "Y"), unit="power"),
        "legacy_capacity"      => VariableDef(type="Float", sets=("P", "Y"), unit="power"),
        "power_in"             => VariableDef(type="Float", sets=("P", "Y", "T"), unit="power"),
        "power_out"            => VariableDef(type="Float", sets=("P", "Y", "T"), unit="power"),
        "total_energy_out"     => VariableDef(type="Float", sets=("P", "Y"), unit="energy"),
        "total_energy_in"      => VariableDef(type="Float", sets=("P", "Y"), unit="energy"),
        "energy_out_time"      => VariableDef(type="Float", sets=("P", "Y", "T"), unit="energy"),
        "energy_in_time"       => VariableDef(type="Float", sets=("P", "Y", "T"), unit="energy"),
        "net_energy_generation"=> VariableDef(type="Float", sets=("C", "Y", "T"), unit="energy"),
        "net_energy_consumption"=> VariableDef(type="Float", sets=("C", "Y", "T"), unit="energy"),
        "storage_level"        => VariableDef(type="Float", sets=("P", "Y", "T"), unit="energy"),
        "max_storage_level"    => VariableDef(type="Float", sets=("P", "Y"), unit="energy")
    )

end
