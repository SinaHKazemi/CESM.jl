# CESM: Compact Energy System Model

CESM is a multimodal energy system model that can be used to model energy systems with different types of energy carriers (electricity, gas, ...) and conversion processes (gas power plant, PV power plants, heat pumps and ...). The primary goal of CESM is to provide a simple, minimal and easy to understand and extend model for research and teaching purposes.

The package is developed in Julia to provide a high performance and easy to use interface and use the power of JuMP for the optimization.

## Documentation Structure

The documentation is organized into the following sections:

- **Tutorials** - Detailed walk-throughs to help you learn how to use CESM
- **How to...** - Directions to help guide your work for a particular task
- **Explanation** - Additional details and background information to help you understand CESM, its structure, and how it works behind the scenes
- **Reference** - Technical references and API for a quick look-up during your work

## FAQ

**Q: Who is this tool for?**  
**A:** Researchers and students exploring energy system concepts and prototypes.

---

**Q: Is this tool suitable for industrial projects?**  
**A:** No, for industrial projects, tools like [*PyPSA*](https://github.com/pypsa/pypsa), [*NREL-Sienna*](https://github.com/NREL-Sienna), [*SpineOpt*](https://github.com/spine-tools/SpineOpt.jl) or [*TulipaEnergy*](https://github.com/TulipaEnergy/TulipaEnergyModel.jl) are better suited.

---

**Q: Does it model detailed electrical power flows?**  
**A:** No, it simplifies by ignoring voltage and phase angle constraints.

---

Throughout the CESM documentation, we strive to follow the [Diataxis](https://diataxis.fr/) documentation framework. There are four main sections containing different information: