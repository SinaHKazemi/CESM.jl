# Variables

In this section, you will learn about the variables definition. The variables are not defined in the config file. They are defined in the `variables.jl` file.

```julia
variables = Dict(
        "total_cost" => (type="Float", sets=(), unit="Money"),
        "capital_cost" => (type="Float", sets=(), unit="Money"),
        "operational_cost" => (type="Float", sets=(), unit="Money"),
        "total_residual_value" => (type="Float", sets=(), unit="Money"),
        "residual_value" => (type="Float", sets=("P", "Y"), unit="Money"),
        "annual_emission" => (type="Float", sets=("Y",), unit="CO2 Emissions"),
        ...
)
```

The `var_` prefix is removed from the variable names since it is not necessary in the code. The keys are the name of the variables. The values are named tuples that contain the following keys:

- `type`: The type of the variable. The type must be one of the following: *Float*, *Integer* or *Boolean*.
- `sets`: This is a tuple containing the sets to which the variable belongs. The tuple members must be taken from the following elements: *Y*, *T*, *C* or *P*.
- `unit`: The unit that the variable represents. The unit must be one of the following: *power*, *energy*, *co2_emissions*, *cost_energy*, *cost_power*, *co2_spec* and *money*.
