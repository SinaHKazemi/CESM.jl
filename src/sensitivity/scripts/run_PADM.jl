include("../../core/CESM.jl")
include("../utils.jl")
include("../PADM.jl")
include("./settings.jl")


using Serialization
using .Utils
using .PADM
using .Settings

for setting in Settings.PADM_settings
    delta_values = PADM.run_PADM(setting)
    if delta_values !== nothing
        serialize(joinpath(Settings.result_folder_path, "PADM_$(Utils.logfile_name(setting)).jls"), delta_values)
    end
end