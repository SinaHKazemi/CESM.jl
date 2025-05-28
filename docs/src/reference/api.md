# API


## Model Initialization

```julia
model = initialize_model(input_file)
optimizee!(model)
write_model_to_file(model)
get_output(model)
write_output_to_file() # either excel or json
```



## Model Extension

```julia
clone_carrier!(input, old_name, new_name)
clone_conversion_process!(input, old_name, new_name, new_carrier_in, new_carrier_out)
disable_conversion_process!(input, name)
enable_conversion_process!(input, name)
```

## Plotting

```julia
plot_results(input, output, plot_type, plot_name)
```