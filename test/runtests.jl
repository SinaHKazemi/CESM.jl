using Test
using Revise


include("../src/CESM.jl")
using .CESM

include("parse_tests.jl")
include("model_tests.jl")