include("../../core/CESM.jl")
include("../utils.jl")
include("../PALM.jl")
include("./settings.jl")


using Serialization
using .Utils
using .PALM
using .Settings


for setting in Settings.PALM_settings
    delta_values = PALM.run_PALM(setting)
    if delta_values !== nothing
        serialize(joinpath(Settings.result_folder_path, "PALM_$(Utils.logfile_name(setting)).jls"), delta_values)
    end
end