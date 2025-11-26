# CESM.jl AI Coding Assistant Instructions

## Project Overview
CESM (Compact Energy System Modeling Tool) is a Julia-based framework for energy system modeling. The project follows a modular architecture with clear separation of concerns:

- `src/core/`: Contains the main components of the system
  - `CESM.jl`: Main module definition and component imports
  - `variables.jl`: Variable definitions and management
  - `components.jl`: Energy system component definitions
  - `model.jl`: Core modeling logic
  - `parser.jl`: Input parsing functionality
  - `visualization.jl`: Data visualization tools

## Development Environment Setup
1. Project requires Julia installation (https://julialang.org/downloads/)
2. Uses Julia's built-in package manager (Pkg)
3. Key dependencies:
   - JuMP: Mathematical optimization
   - GLMakie: Visualization
   - JSON: Data parsing
   - Gurobi/HiGHS/Ipopt: Solvers

## Development Workflow
1. **Project Activation:**
   ```julia
   using Pkg
   Pkg.activate(".")
   Pkg.instantiate()
   ```

2. **Testing:**
   - Tests are organized in `test/` directory
   - Main test files: `parse_tests.jl`, `model_tests.jl`
   - Run tests using: `julia test/runtests.jl`

## Code Patterns and Conventions
1. **Module Structure:**
   - Each core component is in its own file
   - Uses relative imports within the project
   - Example: `using .Variables, .Model, .Components`

2. **Data Handling:**
   - Input data in JSON format (see `examples/Germany/GETM.json` and `examples/House/config.json`)
   - Time series data in `.txt` files under `examples/*/time_series/`

3. **Documentation:**
   - Documentation is built using Documenter.jl
   - Source in `docs/src/`
   - Structure follows Diátaxis framework (tutorials, how-to guides, explanations, reference)

## Common Tasks
1. **Adding New Components:**
   - Define in `src/core/components.jl`
   - Add corresponding variable definitions in `src/core/variables.jl`
   - Include tests in `test/model_tests.jl`

2. **Visualization:**
   - Use GLMakie for plotting
   - SankeyMakie for energy flow diagrams

## Integration Points
- Supports multiple optimization solvers (Gurobi, HiGHS, Ipopt)
- JSON-based configuration for model setup
- Time series data integration for dynamic modeling