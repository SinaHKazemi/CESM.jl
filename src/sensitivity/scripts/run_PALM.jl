include("../../core/CESM.jl")
include("../utils.jl")
include("../PALM.jl")


using Serialization
using .Utils
using .PALM

log_folder_path = "./logs"
if !isdir(log_folder_path)
    mkdir(log_folder_path)
end

result_folder_path = "./results"
if !isdir(result_folder_path)
    mkdir(result_folder_path)
end

settings = [
    Utils.Setting(
        config_file = "./examples/House/config.json",
        manipulation_bound = 0.05,
        manipulated_cp = "PP_Wind",
        target_cp = "Battery",
        target_change = 0.2,
        init_mu = 1.0,
        init_trust_region_radius = 0.05,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path
    ),
    Utils.Setting(
        config_file = "./examples/House/config.json",
        manipulation_bound = 0.05,
        manipulated_cp = "PP_Wind",
        target_cp = "Battery",
        target_change = 0.3,
        init_mu = 1.0,
        init_trust_region_radius = 0.05,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path
    ),
    Utils.Setting(
        config_file = "./examples/House/config.json",
        manipulation_bound = 0.05,
        manipulated_cp = "PP_Wind",
        target_cp = "Battery",
        target_change = 0.4,
        init_mu = 1.0,
        init_trust_region_radius = 0.05,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path
    ),
    Utils.Setting(
        config_file = "./examples/House/config.json",
        manipulation_bound = 0.05,
        manipulated_cp = "PP_Wind",
        target_cp = "Battery",
        target_change = 0.5,
        init_mu = 1.0,
        init_trust_region_radius = 0.05,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path
    )
]

for setting in settings
    delta_values = PALM.run_PALM(setting)
    if delta_values !== nothing
        serialize(joinpath(result_folder_path, "PALM_$(Utils.logfile_name(setting)).jls"), delta_values)
    end
end