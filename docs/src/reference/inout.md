# Input and Output

The input and output data structures are as follows:

## Input

The Input data structure is a struct containing the input data of the model. This datastructure is produced by the `read_input` function that gets config file as input. It has the follwoing fields:

- `units`: a dictionary of  of the `Input` structs that represents the conversions between the units of the input data and the units of the output data.
- `timesteps`: a vector of `Time` structs that represents the time steps of the model.
- `years`: a vector of `Year` structs that represents the years of the model.
- `carriers`: a set of `Carrier` structs that represents the carriers of the model. Each carrier has a unique name.
- `processes`: a set of `Process` structs that represents the processes of the model. Each process has a name, carrier_in and carrier_out fields. The name of each process must be unique.
- `parameters`: a dictionary of dictionaries that contains the parameters of the model. The keys of the dictionary are the names of the parameters and the values are either scalar or dictionaries (possibly nested) that contain the value of the parameter. It has a special key called 'default' that stores the default values of the parameters, if they are defined.

## Output

The output is a dictionary where the keys are the names of the parameters, and the values are dictionaries of indexes and their corresponding values. If the variable type is "Float" or "Integer", zero values are skipped, and if the variable type is "Boolean", false values are skipped.
