## Config File

config file is a json file that contains the configuration of the project.

```json
{
  "units": {..},
  "parameters" : {..},
  "time_steps": [..],
  "years": [..],
  "carriers": {..},
  "conversion_processes": {..}
}
```

## Units

```json
"units": {
    "power":{"input": "GW", "scale": 1, "output": "GW"},
    "energy": {"input": "TWh", "scale": 1000, "output": "GWh"},
    "co2_emissions": {"input": "Mio t", "scale": 1, "output": "Mio t"},
    "cost_energy": {"input": "EUR/MWh", "scale": 0.001, "output": "Mio EUR/GWh"},
    "cost_power": {"input": "EUR/kW", "scale": 1, "output": "Mio EUR/GW"},
    "co2_spec": {"input": "kg/kWh", "scale": 0.001, "output": "Mio t/GWh"},
    "money": {"input": "Mio EUR", "scale": 1, "output": "Mio EUR"}
}
```

The units is a dictionary that must have the `power`, `energy`, `co2_emissions`, `cost_energy`, `cost_power`, `co2_spec` and `money` keys. These keys are the quantities that are referenced in the model parameters.

Each key is a dictionary that must have the `input`, `scale` and `output` keys. The input key is the unit of the input quantity, the scale key is the scale factor that is used to convert the input quantity to the output quantity, and the output key is the unit of the output quantity.

## Parameters

```json
{
    "parameters" : {
        "discount_rate" : {
            "comment": "sets and type properties are mandatory",
            "sets": ["Y"], 
            "type": "Float",
            "value":  0.05
        }, 
        ..
    },
}
```

Any object in the config file could have a `comment` key that will be ignored by the parser.

Each parameter must have a `sets` key that is a list of sets that the parameter belongs to.  The value for the 'sets' key must be a list of string names representing the sets to which the parameter belongs. These sets can be $Y$, $T$, $C$ or $P$.

The `type` key is a string that is the type of the parameter. The type must be one of the following: `Float`, `Integer`, `Boolean` and `String`.

If the the `sets` doesn't contain $C$ and $P$ then the value of the parameter must be defined here. If the `sets` contains $C$ and $P$ then the value of the parameter must be defined in the `carriers` and `conversion_processes` sections.

If the `sets` only contains $Y$ then the value could be an scalar or a piecewise function. A piecewise function could be defined as follows:

```json
"value": [
    {"x": 2020,"y": 19.32},
    {"x": 2030,"y": 32.2}
]
```

The value of the function out of the range of the function is equal to the value of the closest point in the function.


## Time Steps

```json
"time_steps": [1,2,3,4,5]
```

The time steps is a list of integers that represents the time steps of the model.
you could also refer to the file that contains the time steps by its path. The path is either a relative path to the config file or an absolute path. `file.txt` is the same as  `./file.txt`. The format of the file could be csv or txt.

```json
"time_steps": "path/to/file.txt"
```

## Years

Years is a list of integers that represents the years of the model.

```json
"years": [2020,2030,2040]
```

## Carriers

Carriers is a dictionary that contains the carriers of the model. The keys of the dictionary are the names of the carriers and the values are dictionaries that contain the parameters of the carriers. If there is no parameter defined for a carrier then the value could be an empty dictionary.

```json
{
    "carriers": {
        "electricity": {..},
        "heat": {..},
        ...
    },
}
```

If a parameter is defined for a carrier then the value of the parameter must be defined in the `parameters` part of the carrier.

```json
{
    "carriers": {
        "electricity": {
            "comment": "comment for the carrier",
            "parameters": {
                "carrier_plot_color": "blue"
            },
        },
        ..
    },
}
```

## Conversion Processes

conversion processes is a dictionary that contains the conversion processes of the model. The keys of the dictionary are the names of the conversion processes and the values are dictionaries that contain `carrier_in`, `carrier_out` and `parameters` keys.
The `carrier_in` and `carrier_out` keys are the names of the name of the input and output carriers of the conversion process, respectively. The `parameters` key is a dictionary that contains the parameters of the conversion process.

```json
{
    "conversion_processes": {
        "electricity_to_heat": {
            "comment": "comment for the conversion process",
            "carrier_in": "electricity",
            "carrier_out": "heat",
            "parameters": {
                "efficiency": 0.9,
                ..  
            }
        },
    },
}
```

If a parameter is defined over `years` then the value of the parameter could be either a scalar or a piecewise function. If the parameter is defined over `time_steps` then the value of the parameter then the value must be either a scalar or a reference to a file that contains the values of the parameter over the time steps.
