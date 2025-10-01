# Config File

config file is a json file that contains the configuration of the project.
Any object in the config file could have a `_comment` key that will be ignored by the parser. The main structure is as follows:

```json
{
  "units": {..},
  "parameters" : {..},
  "timesteps": [..],
  "years": [..],
  "carriers": [..],
  "processes": [..]
}
```

## Units

```json
"units": {
    "power": {"input": "GW", "scale": 1, "output": "GW"},
    "energy": {"input": "TWh", "scale": 1000, "output": "GWh"},
    "co2_emissions": {"input": "Mio t", "scale": 1, "output": "Mio t"},
    "cost_energy": {"input": "EUR/MWh", "scale": 0.001, "output": "Mio EUR/GWh"},
    "cost_power": {"input": "EUR/kW", "scale": 1, "output": "Mio EUR/GW"},
    "co2_spec": {"input": "kg/kWh", "scale": 0.001, "output": "Mio t/GWh"},
    "money": {"input": "Mio EUR", "scale": 1, "output": "Mio EUR"}
}
```

The units is a dictionary. The keys are not hard coded but in the German model the `power`, `energy`, `co2_emissions`, `cost_energy`, `cost_power`, `co2_spec` and `money` keys are used. These keys are the units that are referenced in the model parameters.

The value corresponding to each key is also a dictionary that must have the `input`, `scale` and `output` keys. The input key is the unit of the input quantity, the scale key is the scale factor that is used to convert the input quantity to the output quantity, and the output key is the unit of the output quantity.

## Time Steps

The time steps is a list of integers that represents the time steps of the model.

```json
"timesteps": [1,2,3,4,5]
```

you could also refer to the file that contains the time steps by its path. The path is either a relative path to the config file or an absolute path. `file.txt` is equivalent to `./file.txt`. The format of the file could be csv or txt.

```json
"timesteps": "path/to/file.txt"
```

## Years

Years is a list of integers that represents the planning years of the model.  Similar to time steps, it can also be passed as an array or a path to the file.

```json
"years": [2020,2030,2040]
```

## Parameters

```json
{
    "parameters" : {
        "discount_rate" : {
            "_comment": "sets and type properties are mandatory",
            "sets": ["Y"], 
            "type": "Float",
            "value":  0.05
        }, 
        ..
    },
}
```

The value of the "parameters" key is also a dictionary. The keys of this dictionary are the parameters of the model, and its value is another dictionary containing the following keys:

### sets

Each parameter must have a `sets` key, which is a list of the sets over which the parameter is indexed.  The value for the 'sets' key must be a list of strings representing the sets over which the parameter is indexed. These sets can be $Y$(years), $T$(timesteps), $C$(carriers) or $P$(processes). The allowable combinations are:

- []
- ["Y"]
- ["P"]
- ["C"]
- ["P", "Y"]
- ["P", "T"]

### type

The value of the `type` key is a string indicating the type of the parameter. It must be one of the following types:

- Float
- Integer
- Boolean
- String

### value

If the value of the `sets` key doesn't contain $C$ or $P$ then the `value` field is mandatory and the value of the parameter must be defined here. If the `sets` contains  $C$ or $P$ then the value of the parameter must be defined in the  `carriers` and `processes` fields, which will be explained later.

If the sets is an empty list then the value of the parameter is a scalar.
If the `sets` is equal to ["Y"] then the value of the parameter could be in one of the following forms:

Scalar like the following example:

```json
"value": 19.32
```

Or a piecewise linear function like this:

```json
"value": [
    {"x": 2020,"y": 19.32},
    {"x": 2030,"y": 32.2}
]
```

This piecewise function must contain at least two points.
The value of the function out of the range of the function is not defined.

## Carriers

`carrires` is a dictionary that contains the carriers of the model.
The keys are the name of the carriers and the values are also dictionaries containing the parameters which are indexed over carriers.

The 'Dummy' carrier must always be included in the list of carriers.

If a parameter is defined for a carrier, then its value must be defined in the corresponding carrier dictionary.

```json
"carriers": {
    "Dummy": {
        "_comment": "optional comment for the carrier"
    },
    "electricity": {
        "carrier_color": "tomato1" 
    },
    "gas": {
        "carrier_color": "orange2"
    },
    // other carriers ...
}
```

## Processes

`processes` is a list of dictionaries that contains the processes of the model. Each dictionary must have `carrier_in` and `carrier_out` keys that are the input and output carriers of the conversion process. The value of the `carrier_in` and `carrier_out` key must be in the list of keys in the `carriers` dictionary.

If a parameter is defined for a process then the value of the parameter must be defined in the dictionary corresponding to that process.

```json
"processes": {
    "electricity_to_gas": {
        "comment": "comment for the process",
        "carrier_in": "electricity",
        "carrier_out": "gas",
    },
    "electricity_to_heat": {
        "comment": "comment for the process",
        "carrier_in": "electricity",
        "carrier_out": "heat"
        "efficiency": 0.9,
        //  other parameters ...
        }
    },
    // other processes ...
}
```

If a parameter is defined over ["P","Y"] then the value of the parameter could be either a scalar or a piecewise function. If the parameter is defined over ["P","T"] then the value of the parameter must be either a scalar or a reference to a file that contains the values of the parameter over all the time steps of a year. For example if the time steps are [1,2,10,11], then the corresponding values to the time steps are the 1th, 2th, 10th and 11th values in the file.
