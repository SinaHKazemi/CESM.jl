# CESM
Compact Energy System Modeling Tool

## Running the Julia Project

**Prerequisites:**

* **Julia Installation:** Ensure you have Julia installed on your system. You can download it from the official Julia website: [https://julialang.org/downloads/](https://julialang.org/downloads/)
* **Package Manager (Pkg):** Julia comes with a built-in package manager called `Pkg`. You'll use this to manage project dependencies.

**Steps to Run the Project:**

1. **Navigate to the Project Directory:** Open your terminal or command prompt and navigate to the directory containing this `Project.toml` file. You can use the `cd` command for this.

    ```bash
    cd /path/to/your/julia_project
    ```

    (Replace `/path/to/your/julia_project` with the actual path to your project directory.)

2. **Activate the Project Environment:** Once inside the project directory, activate the project environment using Julia's `Pkg` manager. This ensures that you are using the specific dependencies defined in your `Project.toml` file.

    Open the Julia REPL (Read-Eval-Print Loop) by typing `julia` in your terminal and pressing Enter.

    ```bash
    julia
    ```

    Inside the Julia REPL, type the following command and press Enter:

    ```julia
    using Pkg
    Pkg.activate(".")
    ```

    The `"."` refers to the current directory, which contains your `Project.toml` file. Julia will then activate the environment associated with this project. You should see the project name in parentheses in your Julia REPL prompt, indicating the environment is active (e.g., `(your_project_name) julia>`).

3.  **Install Dependencies (if necessary):** If this is the first time you are running this project on your system (or if the dependencies have changed), you need to install the required packages listed in the `Project.toml` file. While the project environment is active in the Julia REPL, run the following command:

    ```julia
    Pkg.instantiate()
    ```

    This command will read the `Project.toml` and `Manifest.toml` files and download and install all the necessary dependencies. This might take some time depending on the number and size of the packages.

4.  **Run the Project Code:** Once the environment is activated and the dependencies are installed, you can run your project's main script or any other relevant Julia files.

    * **Running a Main Script:** If your project has a main script (e.g., `src/main.jl` or a file specified for execution), you can run it from the Julia REPL using the `include()` function:

        ```julia
        include("src/main.jl")
        ```

        (Adjust the path to your main script accordingly.)

    * **Interactive Exploration:** You can also interact with your project's modules and functions directly in the Julia REPL after activating the environment and potentially loading your project's main module using `using YourProjectName` (if your project defines a module).
