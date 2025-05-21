# Basics

## Config File

config file is a json file that contains the configuration of the project.

```json
{
    "units": {..},
    "time_steps": [..],
    ""
}
```

## Model


### Sets

- **years**: $Y$
- **time_steps**: $T$
- **carriers**: $C$
- **conversion_processes**: $P$
- **regions**: set of regions that is denoted by $R$.

### Parameters

The input parameters of teh optimization model are defined as follows:

#### Global

- **discount\_rate**: The discount rate is the interest rate used to calculate the present value of future cash flows from a project or investment. For example, at an interest rate of 5%, the value of €100 will increase to €105 in one year. 
  - indices: scalar
  - quantity: dimensionless
  - type: Float
  - default: 0

- **discount\_factor**: Discount factor for each year that is calculated as follows. It is not directly specified in the config file but is calculated from the discount rate.
  - indices: $Y$
  - quantity: dimensionless
  - type: Float
  - default: 0

```math
discount\_factor(y)=(1+discount\_rate)^{y-Y[0]}\quad y \in Y
```

- **annual\_co2\_limit**
- **co2\_price**

#### Storage

- **is\_storage**
- **charge\_efficiency**
- **c\_rate**

#### Legacy

- **max\_legacy\_capacity**: maximum allowed active legacy capacity of a conversion process at a planning year.
  - indices: $P \times Y$
  - quantity: power
  - type: Float
  - default: 0

- **min\_legacy\_capacity**

#### Capacity

- **max\_capacity**
- **min\_capacity**

#### Costs

- **operational\_cost\_energy**
Operational cost per energy output of a conversion process in a year.
  - indices: $Y$
  - quantity: power
  - type: Float
  - default: 0
- **operational\_cost\_energy**
- **operational\_cost\_power**
- **capital\_cost\_power**

#### Fractions

- **min\_fraction\_in**
- **min\_fraction\_out**
- **max\_fraction\_in**
- **max\_fraction\_out**

#### Output Limits

- **max\_energy\_out**
- **min\_energy\_out**

#### Time Series

- **availability\_profile**
- **output\_profile**

#### Technical

- **lifetime**
- **technical\_availability**
- **specific\_co2**
- **efficiency**

### Variables

- **var\_total\_cost**
- **var\_capital\_cost**
- **var\_operational\_cost**
- **var\_total\_residual\_value**
- **var\_residual\_value**
- **var\_annual\_emission**
- **var\_new\_capacity**
- **var\_active\_capacity**
- **var\_legacy\_capacity**
- **var\_power\_in**
- **var\_power\_out**
- **var\_total\_energy\_out**
- **var\_total\_energy\_in**
- **var\_energy\_out\_time**
- **var\_energy\_in\_time**
- **var\_net\_energy\_generation**
- **var\_net\_energy\_consumption**
- **var\_storage\_level**
- **var\_max\_storage\_level**

### Constraints

#### Costs
```math
var\_total\_cost = var\_capital\_cost + var\_operational\_cost
```

#### Power balance


#### CO2


#### Power Output


#### Power-Energy


#### Fractions


#### Capacity


#### Auxiliary Linking Variables



#### Generation


#### Storage



