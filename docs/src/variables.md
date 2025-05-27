# Variables

In this section, you will learn about the variables definition. The variables are not defined in the config file. They are defined in the `variables.jl` file.

```julia
variables = Dict(
        "total_cost" => (type="Float", sets=(), quantity="Money"),
        "capital_cost" => (type="Float", sets=(), quantity="Money"),
        "operational_cost" => (type="Float", sets=(), quantity="Money"),
        "total_residual_value" => (type="Float", sets=(), quantity="Money"),
        "residual_value" => (type="Float", sets=("P", "Y"), quantity="Money"),
        "annual_emission" => (type="Float", sets=("Y",), quantity="CO2 Emissions"),
        ...
)
```

The `var_` prefix is removed from the variable names since it is not necessary in the code. The keys are the name of the variables. The values are named tuples that contain the following keys:

- `type`: The type of the variable. The type must be one of the following: *Float*, *Integer* or *Boolean*.
- `sets`: The sets that the variable belongs to. The sets must be one of the following: *Y*, *T*, *C* or *P*.
- `quantity`: The quantity that the variable represents. The quantity must be one of the following: *power*, *energy*, *co2_emissions*, *cost_energy*, *cost_power*, *co2_spec* and *money*.


<span style="color:red">🚨 Explain about the default value for variables !</span>