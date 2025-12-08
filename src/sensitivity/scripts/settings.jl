module Settings

using ..Utils


log_folder_path = "./logs"
if !isdir(log_folder_path)
    mkdir(log_folder_path)
end

result_folder_path = "./results"
if !isdir(result_folder_path)
    mkdir(result_folder_path)
end

PADM_settings = [
    # Utils.Setting(
    #     config_file = "./examples/House/House_PV_1_week.json",
    #     manipulation_bound = 0.12,
    #     manipulated_cp = "Demand_Electricity",
    #     target_cp = "PP_PV",
    #     target_change = 0.10,
    #     init_mu = 1.0,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path,
    #     max_outer_iterations = 30,
    #     max_inner_iterations = 20
    # ),
    Utils.Setting(
        config_file = "./examples/House/House_PV_1_week.json",
        manipulation_bound = 0.20,
        manipulated_cp = "Demand_Electricity",
        target_cp = "PP_PV",
        target_change = 0.2,
        init_mu = 1.0,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path,
        max_outer_iterations = 30,
        max_inner_iterations = 20
    ),
    # Utils.Setting(
    #     config_file = "./examples/House/House_1_week.json",
    #     manipulation_bound = 0.03,
    #     manipulated_cp = "Demand_Electricity",
    #     target_cp = "PP_PV",
    #     target_change = 0.2,
    #     init_mu = 1.0,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path,
    #     max_outer_iterations = 30,
    #     max_inner_iterations = 20
    # ),
    # Utils.Setting(
    #     config_file = "./examples/House/House_PV_Wind_1_week.json",
    #     manipulation_bound = 0.1,
    #     manipulated_cp = "Demand_Electricity",
    #     target_cp = "PP_PV",
    #     target_change = 0.3,
    #     init_mu = 1.0,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path,
    #     max_outer_iterations = 30,
    #     max_inner_iterations = 20
    # ),
    # Utils.Setting(
    #     config_file = "./examples/House/House_PV_1_week.json",
    #     manipulation_bound = 0.2,
    #     manipulated_cp = "Demand_Electricity",
    #     target_cp = "PP_PV",
    #     target_change = 0.2,
    #     init_mu = 1.0,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path,
    #     max_outer_iterations = 30,
    #     max_inner_iterations = 20
    # ),
    # Utils.Setting(
    #     config_file = "./examples/House/House.json",
    #     manipulation_bound = 0.1,
    #     manipulated_cp = "Demand_Electricity",
    #     target_cp = "PP_PV",
    #     target_change = 0.1,
    #     init_mu = 1.0,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path
    # ),
    # Utils.Setting(
    #     config_file = "./examples/House/House.json",
    #     manipulation_bound = 0.05,
    #     manipulated_cp = "Demand_Electricity",
    #     target_cp = "PP_PV",
    #     target_change = 0.4,
    #     init_mu = 1.0,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path
    # ),
    # Utils.Setting(
    #     config_file = "./examples/House/House.json",
    #     manipulation_bound = 0.05,
    #     manipulated_cp = "Demand_Electricity",
    #     target_cp = "PP_PV",
    #     target_change = 0.5,
    #     init_mu = 1.0,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path
    # )
]


PALM_settings = [
    # Utils.Setting(
    #     config_file = "./examples/House/House_PV_1_week.json",
    #     manipulation_bound = 0.15,
    #     manipulated_cp = "PP_PV",
    #     target_cp = "PP_PV",
    #     target_change = 0.15,
    #     init_mu = 1.0,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path,
    #     max_outer_iterations = 30,
    #     max_inner_iterations = 20
    # ),
    # Utils.Setting(
    #     config_file = "./examples/House/House_PV_Wind_1_week.json",
    #     manipulation_bound = 0.2,
    #     manipulated_cp = "PP_Wind",
    #     target_cp = "PP_PV",
    #     target_change = 0.5,
    #     init_mu = 1.0,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path,
    #     max_outer_iterations = 30,
    #     max_inner_iterations = 20
    # ),
    Utils.Setting(
        config_file = "./examples/House/House_PV_Wind_1_week.json",
        manipulation_bound = 0.2,
        manipulated_cp = "PP_Wind",
        target_cp = "PP_PV",
        target_change = 0.4,
        init_mu = 1.0,
        min_stationary_change = 1e-4,
        min_obj_improvement_rate = 1e-2,
        last_year = 2050,
        log_folder_path = log_folder_path,
        max_outer_iterations = 30,
        max_inner_iterations = 20
    ),
    # Utils.Setting(
    #     config_file = "./examples/House/House_PV_Wind.json",
    #     manipulation_bound = 0.05,
    #     manipulated_cp = "PP_Wind",
    #     target_cp = "PP_PV",
    #     target_change = 0.05,
    #     init_mu = 1.0,
    #     init_trust_region_radius = 0.05,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path
    # ),
    # Utils.Setting(
    #     config_file = "./examples/House/House.json",
    #     manipulation_bound = 0.05,
    #     manipulated_cp = "PP_Wind",
    #     target_cp = "Battery",
    #     target_change = 0.3,
    #     init_mu = 1.0,
    #     init_trust_region_radius = 0.05,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path
    # ),
    # Utils.Setting(
    #     config_file = "./examples/House/House.json",
    #     manipulation_bound = 0.05,
    #     manipulated_cp = "PP_Wind",
    #     target_cp = "Battery",
    #     target_change = 0.4,
    #     init_mu = 1.0,
    #     init_trust_region_radius = 0.05,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path
    # ),
    # Utils.Setting(
    #     config_file = "./examples/House/House.json",
    #     manipulation_bound = 0.05,
    #     manipulated_cp = "PP_Wind",
    #     target_cp = "Battery",
    #     target_change = 0.5,
    #     init_mu = 1.0,
    #     init_trust_region_radius = 0.05,
    #     min_stationary_change = 1e-4,
    #     min_obj_improvement_rate = 1e-2,
    #     last_year = 2050,
    #     log_folder_path = log_folder_path
    # )
]


end