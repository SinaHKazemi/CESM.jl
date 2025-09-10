# Model

Here we define the mathematical model of the optimization problem.

## Sets

- **years**: an ordered set of years, denoted by $Y$.
- **timesteps**: an ordered set of time steps selection, denoted by $T$.
- **carriers**: an unordered set of energy carriers, denoted by $C$. Each carrier $c \in C$ has a name $c.name$. Two carriers are equal if they have the same name. `Dummy` is a special carrier that is used to represent the carriers out of the model.
- **processes**: an unordered set of conversion processes, denoted by $P$.
Each process $p \in P$ has a name $p.name$, input carrier $p.carrier\_in$, output carrier $p.carrier\_out$.
Two process are equal if they have the same name, input carrier and output carrier.
The subset of $P$ that contains storage conversion processes is denoted by $S$.

## Parameters

The input parameters of the optimization model are listed below.
The ranges are not validated in the code, but rather imply that the model is rational within these ranges.

### General

- **discount\_rate**: The discount rate is the interest rate used to calculate the present value of future cash flows from a project or investment. For example, if we expect to invest €105 next year, at an interest rate of 5% this amount is worth today: $PV=\frac{FV}{1+r}​=\frac{105}{1.05}​=100$
  - indices: $\emptyset$ (scalar)
  - unit: unitless
  - type: Float
  - default: 0
  - Range: [0,$\infty$]

- **discount\_factor[y]**: Discount factor for each year that is calculated as follows. It is not directly specified in the config file but is calculated from the discount rate.
  - indices: $Y$
  - unit: unitless
  - type: Float
  - default: 0
  - Range: [0,$\infty$]

```math
\text{discount\_factor}[y]=(1+\text{discount\_rate})^{y-Y[0]},\quad y \in Y.
```

The notation $Y[0]$ is the first planning year of the model.

- **dt**: Time step size. It shows how many hours each time step represents. A a model with hourly time resolution, $dt$ is equal to $1$.
  - indices: $\emptyset$ (scalar)
  - unit: unitless
  - type: Integer
  - range: [1,8760]

- **w**:  weight of each time step withim the whole year. It is not directly specified in the config file but is calculated from the time step duration and is equal to $8760/(dt*|T|)$ where $|T|$ is the number of time steps and $8760$ is the number of hours in a year. The number of time steps provided, $|T|$, must be such that $8760$ is divisible by $dt*|T|$.
  - indices: $\emptyset$ (scalar)
  - unit: unitless
  - type: Integer
  - range: [1,8760]

### CO2

- **annual\_co2\_limit[y]**: Annual CO2 emission limit of the energy system in year $y \in Y$.
  - indices: $Y$
  - unit: CO2 Mass
  - type: Float
  - default: 0
  - range: [0,$\infty$]

- **co2\_price[y]**: CO2 price for emission from the energy system  in year $y \in Y$.
  - indices: $Y$
  - unit: Money/CO2 Mass
  - type: Float
  - default: 0
  - range: [0,$\infty$]

### Storage

- **is\_storage[p]**: Indicates if the conversion process $p \in P$ is a storage process.
  - indices: $P$
  - unit: unitless
  - type: Boolean
  - default: false
  - range: {true, false}

- **charge\_efficiency[p]**: Efficiency of charging of storage conversion process $p \in P$.
  - indices: $P$
  - unit: unitless
  - type: Float
  - default: 1
  - range: (0,1]

- **c\_rate[p]**: indicates the discharge and charging rate of the storage conversion process $p \in P$. A c_rate of 2 means that the full storage can be fully discharged in (1 hour)/2=30 minutes.
  - indices: $P$
  - unit: unitless
  - type: Float
  - range: (0,1]

### Legacy

Legacy conversion processes are those that existed before the planning period.

- **max\_legacy\_capacity[p,y]**: maximum allowed active legacy capacity of conversion process $p \in P$ in year $y \in Y$. For example, it could be used to model a long-term policy for shutting down coal power plants. Even though the plant's lifetime has not ended, you enforce the shutdown.
  - indices: $P \times Y$
  - unit: power
  - type: Float
  - default: 0

- **min\_legacy\_capacity[p,y]**: minimum allowed active legacy capacity of conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: power
  - type: Float
  - default: 0
  - range: [0,$\infty$]

### Capacity

- **max\_capacity[p,y]**: maximum allowed active capacity of conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: power
  - type: Float
  - default: 0
  - range: [0,$\infty$]

- **min\_capacity[p,y]**: minimum allowed active capacity of conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: power
  - type: Float
  - default: 0
  - range: [0,$\infty$]

### Costs

- **operational\_cost\_energy[p,y]**: Operational cost per energy output of conversion process $p \in P$ in a year.
  - indices: $P \times Y$
  - unit: Money/Energy
  - type: Float
  - default: 0
  - range: [0,$\infty$]

- **operational\_cost\_power[p,y]**: Operational cost per active capacity of conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: Money/Power
  - type: Float
  - default: 0
  - range: [0,$\infty$]

- **capital\_cost\_power[p,y]**: Capital cost per active capacity of conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: Money/Power
  - type: Float
  - default: 0
  - range: [0,$\infty$]

### Fractions

- **min\_fraction\_in[p,y]**: Minimum fraction of the input carrier(carrier_in) consumed by conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: dimensionless
  - type: Float
  - default: 0
  - range: [0,1]

- **min\_fraction\_out[p,y]**: Minimum fraction of the output carrier(carrier_out) generated by conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: dimensionless
  - type: Float
  - default: 0
  - range: [0,1]

- **max\_fraction\_in[p,y]**: Maximum fraction of the input carrier(carrier_in) consumed by conversion process $p \in P$ in year $y \in Y$.
  
  - indices: $P \times Y$
  - unit: dimensionless
  - type: Float
  - default: 1
  - range: [0,1]

- **max\_fraction\_out[p,y]**: Maximum fraction of the output carrier(carrier_out) generated by conversion process $p \in P$ in year $y \in Y$.

  - indices: $P \times Y$
  - unit: dimensionless
  - type: Float
  - default: 1
  - range: [0,1]

### Energy Output Limits

- **max\_energy\_out[p,y]**: Maximum energy output of conversion process $p \in P$ in year $y \in Y$.

  - indices: $P \times Y$
  - unit: Energy
  - type: Float
  - default: $\infty$
  - range: [0,$\infty$]

- **min\_energy\_out[p,y]**: Minimum energy output of conversion process $p \in P$ in year $y \in Y$.

  - indices: $P \times Y$
  - unit: Energy
  - type: Float
  - default: 0
  - range: [0,$\infty$]

### Time Series

- **availability\_profile[p,t]**: Availability profile of conversion process $p \in P$ at  time step $t \in T$. If the availability parameter of a wind turbine is $0.5$, then 50% of the available active capacity could be utilized.

  - indices: $P \times T$
  - unit: dimensionless
  - type: Float
  - default: 1
  - Range: [0,1]

- **output\_profile[p,t]**: Share of the annual energy output supplied by the conversion process $p \in P$ at time step $t \in T$ such that:  $$\sum_{t \in T}output\_profile[p,t]=1, \quad \forall p \in P.$$

  - indices: $P \times T$
  - unit: dimensionless
  - type: Float
  - default: 1
  - Range: [0,1]

### Technical

- **lifetime[p]**: Technical lifetime of conversion process $p \in P$ in years.
  - indices: $P$
  - unit: Time
  - type: Integer
  - default: 100
  - range: [1,$\infty$]

- **technical\_availability[p]**: Technical availability of conversion process $p \in P$. For example, if the technical availability of a gas power plant is $0.9$, then it can only be utilized 90% of the year based solely on technical factors.

  - indices: $P$
  - unit: dimensionless
  - type: Float
  - default: 1
  - range: [0,1]

- **specific\_co2[p]**: Specific CO2 emission intensity per energy output of conversion process $p \in P$.

  - indices: $P$
  - unit: CO2 Mass/Energy
  - type: Float
  - default: 0
  - range: [0,$\infty$]

- **efficiency[p]**: Efficiency of conversion process $p \in P$.
  
  - indices: $P$
  - unit: dimensionless
  - type: Float
  - default: 1
  - Range: [0,1]

## Variables

All variables are non-negative unless otherwise specified.

### Costs

- **var\_total\_cost**: Total cost.
  - indices: $\emptyset$ (scalar)
  - unit: Money
  - type: Float

- **var\_capital\_cost**: Capital cost.
  - indices: $\emptyset$ (scalar)
  - unit: Money
  - type: Float

- **var\_operational\_cost**: Operational cost.
  - indices: $\emptyset$ (scalar)
  - unit: Money
  - type: Float

- **var\_residual\_value[p,y]**: The residual value is the present value of a property at the end of a planning period. This variable represents the residual value of the conversion process $p \in P$ that is built in year $y \in Y$.
  - indices: $P \times Y$
  - unit: Money
  - type: Float

- **var\_total\_residual\_value**: Total residual value.
  - indices: $\emptyset$ (scalar)
  - unit: Money
  - type: Float

### CO2

- **var\_annual\_emission[y]**: Annual CO2 emission from the energy system in year $y \in Y$.
  - indices: $Y$
  - unit: CO2 Mass
  - type: Float

### Capacity

- **var\_new\_capacity[p,y]**: New capacity of conversion process $p\in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: Power
  - type: Float

- **var\_active\_capacity[p,y]**: Active capacity of conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: Power
  - type: Float

- **var\_legacy\_capacity[p,y]**: Active legacy capacity of conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: Power
  - type: Float

### Power and Energy

- **var\_power\_in[p,y,t]**: Power input of conversion process $p \in P$ in year $y \in Y$ at time step $t \in T$.
  - indices: $P \times Y \times T$
  - unit: Power
  - type: Float

- **var\_power\_out[p,y,t]**: Power output of conversion process $p \in P$ in year $y \in Y$ at time step $t \in T$.
  - indices: $P \times Y \times T$
  - unit: Power
  - type: Float

- **var\_total\_energy\_out[p,y]**: Total energy output of conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: Energy
  - type: Float

- **var\_total\_energy\_in**: Total energy input of conversion process $p \in P$ in year $y \in Y$.
  - indices: $P \times Y$
  - unit: Energy
  - type: Float

- **var\_energy\_out\_time**: Energy output of conversion process $p \in P$ in year $y \in Y$ at time step $t \in T$.
  - indices: $P \times Y \times T$
  - unit: Energy
  - type: Float

- **var\_energy\_in\_time[p,y,t]**: Energy input of conversion process $p \in P$ in year $y \in Y$ at time step $t \in T$.
  - indices: $P \times Y \times T$
  - unit: Energy
  - type: Float

- **var\_net\_energy\_generation[c,y,t]**: Net energy generation of energy carrier $c \in C$ in year $y \in Y$ at time step $t \in T$.
  - indices: $C \times Y \times T$
  - unit: Energy
  - type: Float

- **var\_net\_energy\_consumption[c,y,t]**: Net energy consumption of energy carrier $c \in C$ in year $y \in Y$ at time step $t \in T$.
  - indices: $C \times Y \times T$
  - unit: Energy
  - type: Float

### Storage

- **var\_storage\_level[p,y,t]**: Storage level of a storage conversion process $p \in P$ in year $y\in Y$ at time step $t\in T$.
  - indices: $P \times Y \times T$
  - unit: Energy
  - type: Float

- **var\_max\_storage\_level[p,y]**: The maximum energy capacity of the storage conversion process $p \in P$ in year $y\in Y$.
  - indices: $P \times Y$
  - unit: Energy
  - type: Float

## Constraints

In all constraints, if a parameter is not defined, the default value is used. If a default value is not defined, the constraint is not included in the model.

### Costs

- Total cost is the sum of operational and capital costs. The default objective function is also the total cost.

```math
\text{var\_total\_cost} = \text{var\_capital\_cost} + \text{var\_operational\_cost}
```


- Capital cost is equal to the present value of all capital expenditures minus the residual value.

```math
\begin{align*}
\text{var\_capital\_cost} &= \sum_{y \in Y} 
\left(
  \text{discount\_factor}[y] * \sum_{p \in P} 
    \left(
      \text{var\_new\_capacity}[p, y] * \text{capital\_cost\_power}[p,y]
    \right)
\right)\\
&- \text{var\_total\_residual\_value}
\end{align*}
```

- Operational costs comprise the expenses of producing energy, keeping the system running, and any CO₂ emission penalties. In the following equation, $y^+$ is the planning year after $y$.

```math
\begin{align*}
\text{var\_operational\_cost} &=
\sum_{p\in P}\sum_{y \in Y} 
\text{discount\_factor}[y] \\
& * ( \\
  & \quad \text{var\_active\_capacity}[p,y] * \text{operational\_cost\_power}[p,y] +\\
  & \quad \text{var\_total\_energy\_out}[p,y] * \text{operational\_cost\_energy}[p,y] +\\
  & \quad \text{var\_annual\_emission}[y] * \text{co2\_price}[y]\\
&) * \left(y^+-y\quad \text{if} \quad y \neq Y[end] \quad \text{else} \quad 1 \right)
\end{align*}
```

- The residual value of the new capacity of conversion process $p \in P$ built in $y \in Y$.

```math
\begin{align*}
\text{var\_residual\_value}[p,y] &= \text{var\_new\_capacity}[y] * \text{capital\_cost\_power}[p,y] \\
&* (1 - \frac{Y[end]-y+1}{\text{lifetime}[p]}) * \text{discount\_factor}[y], \quad \forall y\in Y,\forall p \in P, \quad \text{if} \quad Y[end] - y + 1 < \text{lifetime}[p]
\end{align*}
```

- The sum of residual values over all $y \in Y$ and $p \in P$.

```math
\text{var\_total\_residual\_value} = \sum_{p \in P} \sum_{y \in Y} \text{var\_residual\_value}[y] \quad \text{if} \quad Y[end] - y + 1< \text{lifetime}[p]
```

### Power balance

- The power balance equation applies to all energy carriers except the dummy.

```math
\sum_{p \in P | p.carrier\_in=c} \text{var\_power\_in}[p,y,t] = 
\sum_{p \in P | p.carrier\_out=c} \text{var\_power\_out}[p,y,t], \quad \forall c \in C\setminus \{Dummy\}, \forall y \in Y, \forall t \in T
```

### CO2

- The co2 emission in year $y \in Y$ is the sum of emissions from all conversion processes.

```math
\text{var\_annual\_emission}[y] = \sum_{p \in P} \text{var\_total\_energy\_out}[p,y] * \text{specific\_co2}[p], \quad \forall y \in Y
```

- The annual CO2 emission must not exceed the limit set by the user.

```math
\text{var\_annual\_emission}[y] \leq \text{annual\_co2\_limit}[y], \quad \forall y \in Y
```

### Power Output

- The output is limited by the efficieny of the process. It doesn't apply to storage processes.

```math
\text{var\_power\_out}[p,y,t] = \text{var\_power\_in}[p,y,t] * \text{efficiency}[p], \quad \forall p \in P\setminus S, \forall y \in Y, \forall t \in T
```

- The output is limited by the technical availability of the process.

```math
\text{var\_power\_out}[p,y,t] \leq \text{var\_active\_capacity}[p,y] * \text{technical\_availability}[p], \quad \forall p \in P, \forall y \in Y, \forall t \in T
```

- The output of renewables are limited by the availability of the process.

```math
\text{var\_power\_out}[p,y,t] \leq \text{var\_active\_capacity}[p,y] * \text{availability\_profile}[p,t], \quad \forall p \in P, \forall y \in Y, \forall t \in T
```

### Power-Energy

- The energy output (or input) of a conversion process at a given time is equal to the power at that time multiplied by the length of the time interval in hours($dt$). This value is also multiplied by $w$, which is the weight of that timestep in a year.

```math
\text{var\_energy\_out\_time}[p,y,t] = \text{var\_power\_out}[p,y,t] * \text{dt} * \text{w}, \quad \forall p \in P, \forall y \in Y, \forall t \in T
```

```math
\text{var\_energy\_in\_time}[p,y,t] = \text{var\_power\_in}[p,y,t] * \text{dt} * \text{w} \quad \forall p \in P, \forall y \in Y, \forall t \in T
```

### Fractions

```math
\text{var\_energy\_out\_time}[p,y,t] \geq \text{min\_fraction\_out}[p,y] * \text{var\_net\_energy\_generation}[p.carrier\_out,y,t] \quad \forall p \in P, \forall y \in Y, \forall t \in T
```

```math
\text{var\_energy\_out\_time}[p,y,t] \leq \text{max\_fraction\_out}[p,y] * \text{var\_net\_energy\_generation}[p.carrier\_out,y,t] \quad \forall p \in P, \forall y \in Y, \forall t \in T
```

```math
\text{var\_energy\_in\_time}[p,y,t] \geq \text{min\_fraction\_in}[p,y] * \text{var\_net\_energy\_consumption}[p.carrier\_in,y,t] \quad \forall p \in P, \forall y \in Y, \forall t \in T
```

```math
\text{var\_energy\_in\_time}[p,y,t] \leq \text{max\_fraction\_in}[p,y] * \text{var\_net\_energy\_consumption}[p.carrier\_in,y,t] \quad \forall p \in P, \forall y \in Y, \forall t \in T
```

### Capacity

- Maximum and minimum of the legacy capacity

```math
\text{var\_legacy\_capacity}[p,y] \leq \text{max\_legacy\_capacity}[p,y] \quad \forall p \in P, \forall y \in Y
```

```math
\text{var\_legacy\_capacity}[p,y] \geq \text{min\_legacy\_capacity}[p,y] \quad \forall p \in P, \forall y \in Y
```

- Upper limit for the active capacity

```math
\text{var\_active\_capacity}[p,y] \leq \text{var\_legacy\_capacity}[p,y] + 
\sum_{y'\in Y, | y-\text{lifetime}[p]|<y'\leq y}\text{var\_new\_capacity}[p,y'] \quad \forall p \in P, \forall y \in Y
```

- Maximum and minimum of the active capacity

```math
\text{var\_active\_capacity}[p,y] \leq  \text{max\_capacity}[p,y] \quad \forall p \in P, \forall y \in Y
```

```math
\text{var\_active\_capacity}[p,y] \geq  \text{min\_capacity}[p,y] \quad \forall p \in P, \forall y \in Y
```

### Auxiliary Linking Variables

```math
\text{var\_total\_energy\_out}[p,y] = \sum_{t \in T} \text{var\_energy\_out\_time}[p,y,t] \quad \forall p \in P, \forall y \in Y
```

```math
\text{var\_total\_energy\_in}[p,y] = \sum_{t \in T} \text{var\_energy\_in\_time}[p,y,t] \quad \forall p \in P, \forall y \in Y
```

```math
\text{var\_net\_energy\_generation}[c,y,t] = \sum_{p\in P|p.carrier\_out=c}
\text{var\_energy\_out\_time}[p,y,t] \quad \forall c \in C, \forall y \in Y, \forall t \in T
```

```math
\text{var\_net\_energy\_consumption}[c,y,t] = \sum_{p\in P|p.carrier\_in=c}
\text{var\_energy\_in\_time}[p,y,t] \quad \forall c \in C, \forall y \in Y, \forall t \in T
```

### Generation

- Minimum and maximum of the energy output

```math
\text{var\_total\_energy\_out}[p,y] \leq \text{max\_energy\_out}[p,y] \quad \forall p \in P, \forall y \in Y
```

```math
\text{var\_total\_energy\_out}[p,y] \geq \text{min\_energy\_out}[p,y] \quad \forall p \in P, \forall y \in Y
```

- The output profile is used to model demands

```math
\text{var\_energy\_out\_time}[p,y,t] = \text{var\_total\_energy\_out}[p,y] 
* \text{output\_profile}[p,t] \quad \forall p \in P, \forall y \in Y, \forall t \in T
```

### Storage

Let $S\subseteq P$ be the set of conversion processes that are storage processes.

```math
S = \{p \in P | p.is\_storage\}
```

then

- The active capacity of a storage is the maximum throughput power. The following constraint calculates the maximum capacity of the storage

```math
\text{var\_max\_storage\_level}[s,y] = \text{var\_active\_capacity}[s,y]/\text{c\_rate}[s] \quad \forall s \in S, \forall y \in Y
```

- Doesn't let the storage level to be more than the maximum capacity

```math
\text{var\_storage\_level}[s,y,t] \leq \text{var\_max\_storage\_level}[s,y] \quad \forall s \in S, \forall y \in Y, \forall t \in T
```

- The active capacity of the storage is its maximum throughput power.

```math
\text{var\_power\_in}[s,y,t] \leq \text{var\_active\_capacity}[s,y] \quad \forall s \in S, \forall y \in Y, \forall t \in T
```

```math
\begin{align*}
\text{var\_storage\_level}[s,y,t] &= \text{var\_storage\_level}[s,y,t^{-}] \\
&+ \text{var\_power\_in}[s,y,t] * \text{dt} * \text{charge\_efficiency}[s]\\
&- \text{var\_power\_out}[s,y,t] * \text{dt} / \text{efficiency}[s]
\quad \forall s \in S, \forall y \in Y, \forall t \in T
\end{align*}
```

notaion $t^-$ is the previous time step of $t$. For the first time step, $t^-$ is the last time step.