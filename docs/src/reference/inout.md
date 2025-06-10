# Input and Output

Here we explain about the Input and Output datastructures.

## Input

The Input datastructure is a dictionary that contains the input data of the model. This datastructure is produced by the `read_input` function that gets configuration file as input. The input datastructure is a dictionary that contains the following keys:

- `units`: a dictionary that contains the units of the input data.
- `parameters`: a dictionary that contains the parameters of the model.
- `tss`: a list of integers that represents the time steps selection of the model.
- `years`: a list of integers that represents the years of the model.
- `carriers`: a list that contains the carriers of the model.
- `conversion_processes`: a dictionary that contains the conversion processes of the model. The keys of the dictionary are the names of the conversion processes and the values are dictionaries that contain the `carrrier_in` and `carrier_out` carriers of the conversion process.

```julia
Input = Dict(
    "units" => ...,
    "tss" => ...,
    "years" => ...,
    "carriers" => ...,
    "processes" => ...
    "parameters" => ...,
)
```

The `parameters` is a dictionary that contains the parameters of the model. The keys of the dictionary are the names of the parameters and the values are either scalar or dictionaries (possibly nested) that contaon the value of the parameter.

If the value is defined over $P$ and $Y$ then the value of the parameter is a nested dictionary.

```julia
input["parameters"]["max_capacity"]["electricity_to_heat"][2020]
```

gives you the value of the parameter *max_capacity* for the conversion process *electricity_to_heat* in the year *2020*.

`parameters` dictionary also has a special key `defaults` which is a dictionary that contains the default values of the parameters. The key is the name of the parameter and the value is the default scalar value.

If the value is not defined for *electricity_to_heat* conversion process, then the following is not defined:

```julia
input["parameters"]["max_capacity"]
```

## Output

The Output datastructure is also a dictionary. The keys are the names of the variables and similar to the input parameters, the values are either scalar or dictionaries (possibly nested) that contain the optimal values of the variables.

```julia
output = Dict(
    "annual_emission" => ...,
    "new_capacity" => ...,
    "active_capacity" => ...
)
```

