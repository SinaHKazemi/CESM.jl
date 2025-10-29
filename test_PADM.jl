include("./src/core/CESM.jl")
include("./src/sensitivity/PADM.jl")
using .CESM
using .PADM
CONFIG_FILE_ADDRESS = "./examples/House/config.json"
input = CESM.Parser.parse_input(CONFIG_FILE_ADDRESS)
PADM.PADM_alg(input)