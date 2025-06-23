## Config File

config file is a json file that contains the configuration of the project.
Any object in the config file could have a `comment` key that will be ignored by the parser.

```json
{
  "units": {..},
  "parameters" : {..},
  "timesteps": [..],
  "regions": [..],
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

The units is a dictionary that must have the `power`, `energy`, `co2_emissions`, `cost_energy`, `cost_power`, `co2_spec` and `money` keys. These keys are the quantities that are referenced in the model parameters.

Each key is a dictionary that must have the `input`, `scale` and `output` keys. The input key is the unit of the input quantity, the scale key is the scale factor that is used to convert the input quantity to the output quantity, and the output key is the unit of the output quantity.

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

Years is a list of integers that represents the years of the model.

```json
"years": [2020,2030,2040]
```

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

### sets

Each parameter must have a `sets` key that is a list of sets that the parameter belongs to.  The value for the 'sets' key must be a list of string names representing the sets to which the parameter belongs. These sets can be $Y$, $T$, $R$, $C$ or $P$. The allowable combinations are:

- []
- ["Y"]
- ["P"]
- ["C"]
- ["R"]
- ["P", "Y"]
- ["P", "T"]

### type

The `type` key is a string that is the type of the parameter. The type must be one of the following:

- Float
- Integer
- Boolean
- String

### value

If the the `sets` doesn't contain $R$, $C$ or $P$ then the `value` field is mandatory and the value of the parameter must be defined here. If the `sets` contains $R$, $C$ or $P$ then the value of the parameter must be defined in the `regions`, `carriers` and `processes` fields, resspectively.

If the sets is an empty list then the value of the parameter is a scalar.

If the `sets` is equal to ["Y"] then the value of the parameter could be in one of the following forms:

- Scalar

```json
"value": 19.32
```

- Piecewise linear function

```json
"value": [
    {"x": 2020,"y": 19.32},
    {"x": 2030,"y": 32.2}
]
```

The value of the function out of the range of the function is equal to the value of the closest point in the function.

## Regions

Regions is a list of strings that represents the regions of the model. region `Global` must be included in the list.

```json
"regions": ["Global","Germany","Belgium"]
```

## Carriers

`carrires` is a list of dictionaries that contains the carriers of the model. Each dictinary must have a `name` key that is the name of the carrier and a `region` key that is the region of the carrier. The value of the `region` key must be one of the regions in the `regions` list.

The 'Dummy' carrier in the 'Global' region must always be included in the list of carriers.

If a parameter is defined for a carrier then the value of the parameter must be defined in the `parameters` part of the carrier.

```json
"carriers": [
    {
        "name": "Dummy",
        "region": "Global"
    },
    {
        "name": "electricity",
        "region": "Germany"
    },
    {
        "comment": " optional comment for the carrier",
        "name": "gas",
        "region": "Belgium",
        "parameters": {
            "carrier_plot_color": "blue"
        }
    },
    // other carriers ...
]
```

## Processes

`processes` is a list of dictionaries that contains the processes of the model. Each dictinary must have a `name` key that is the name of the process, a `carrier_in` key that is the input carrier of the conversion process and a `carrier_out` key that is the output carrier of the process. The value of the `carrier_in` and `carrier_out` key must be one of the carriers in the `carriers` list.

If a parameter is defined for a process then the value of the parameter must be defined in the `parameters` part of the process.

```json
"processes": {
    "electricity_to_gas": {
        "comment": "comment for the process",
        "carrier_in":{
            "name": "electricity",
            "region": "Germany"
        },
        "carrier_out": {
            "name": "gas",
            "region": "Belgium"
        }
    },
    "electricity_to_heat": {
        "comment": "comment for the process",
        "carrier_in":{
            "name": "electricity",
            "region": "Germany"
        },
        "carrier_out": {
            "name": "heat",
            "region": "Belgium"
        },
        "parameters": {
            "efficiency": 0.9,
            //  other parameters ...
        }
    },
    // other processes ...
}
```

If a parameter is defined over ["P","Y"] then the value of the parameter could be either a scalar or a piecewise function. If the parameter is defined over ["P","T"] then the value of the parameter must be either a scalar or a reference to a file that contains the values of the parameter over all the time steps of a year. For example if the time steps are [1,2,10,11], then the corresponding values to the time steps are the 1th, 2th, 10th and 11th values of the file.
