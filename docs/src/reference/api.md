# API and CLI

There are two ways to run the model, via the command line interface (CLI) or through the API.
The CLI is a simple way to run the model and is suitable for users who are not familiar with programming. The API is a more flexible way to run the model and is suitable for users who are familiar with programming and are looking for more control over the model.


## CLI

## Run a simulation

## Plot results


## API


### Model Initialization

```julia
model = initialize_model(input_file)
optimizee!(model)
write_model_to_file(model)
get_output(model)
write_output_to_file() # either excel or json
```



### Model Extension

```julia
clone_carrier!(input, old_name, new_name)
clone_conversion_process!(input, old_name, new_name, new_carrier_in, new_carrier_out)
disable_conversion_process!(input, name)
enable_conversion_process!(input, name)
```

### Plotting

```julia
plot_results(input, output, plot_type, plot_name)
```