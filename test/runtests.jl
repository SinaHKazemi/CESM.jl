using Test
using PrettyPrinting
include("../src/parser.jl")

@testset "MyPackage Tests" begin
    # parse_units
    units = Dict(
        "energy" => Dict("input" => "TWh", "scale" => 1000, "output" => "GWh", "another_key" => "value"),
        "power" => Dict("input" => "GW", "scale" => 1.0, "output" => "GW"),
        "co2_emissions" => Dict("input" => "Mio t", "scale" => 1, "output" => "Mio t"),
    )
    @test_throws Parse.InvalidParameterError Parse.get_units(units)
    units = Dict(
        "energy" => Dict("input" => "TWh", "scale" => "12", "output" => "GWh"),
        "power" => Dict("input" => "GW", "scale" => 1.0, "output" => "GW"),
        "co2_emissions" => Dict("input" => "Mio t", "scale" => 1, "output" => "Mio t"),
    )
    @test_throws Parse.InvalidParameterError Parse.get_units(units)
    units = Dict(
        "energy" => Dict("input" => "TWh", "scale" => 12, "output" => "GWh"),
        "power" => Dict("input" => "GW", "scale" => 1.0, "output" => "GW"),
        "co2_emissions" => Dict("input" => "Mio t", "scale" => 1, "output" => "Mio t"),
    )

    @test Parse.get_units(units) == Dict(
        "energy" => Dict("input" => "TWh", "scale" => 12.0, "output" => "GWh"),
        "power" => Dict("input" => "GW", "scale" => 1.0, "output" => "GW"),
        "co2_emissions" => Dict("input" => "Mio t", "scale" => 1.0, "output" => "Mio t"),
    )

    # parse data file
    @test Parse.parse_data_file("./testdata/data_int.txt", dirname(@__FILE__), Int) == [1,2,3,4,5,6]  # Expected output is just a printed message
    @test Parse.parse_data_file("./testdata/data_float.txt", dirname(@__FILE__), Float64) == [1,2,3,4,5.2,6.7]  # Expected output is just a printed message
    # get_vector_or_file
    @test Parse.get_vector_or_file([1,2,3,4,5,6], Int, dirname(@__FILE__)) == [1,2,3,4,5,6]
    @test Parse.get_vector_or_file("./testdata/data_int.txt", Int, dirname(@__FILE__)) == [1,2,3,4,5,6]
    # validate_temporal_sequence
    @test_throws Parse.TemporalSequenceError Parse.validate_temporal_sequence([1,2,3,4,6,5])
    @test_throws Parse.TemporalSequenceError Parse.validate_temporal_sequence([-1,0,1,2,3])
    # parse_tss
    @test Parse.parse_tss([1,2,3,4,5,6], dirname(@__FILE__)) == [1,2,3,4,5,6]
    # parse_years
    @test Parse.parse_years([1,2,3,4,5,6], dirname(@__FILE__)) == [1,2,3,4,5,6]
    # parse carriers
    data = Dict(
        "carriers" => Dict(
            "gas" => Dict(
                "comment" => "gas carrier",
                "parameters" => Dict(
                    "param1" => 1,
                    "param2" => 2,
                )
            ),
            "oil" => Dict(
                "comment" => "oil carrier",
                "parameters" => Dict(
                    "param3" => 3,
                    "param4" => 4,
                )
            )
        ),
        "processes" => Dict(
            "gas_to_oil" => Dict(
                "carrier_in" => "gas",
                "carrier_out" => "oil",
            ),
            "oil_to_gas" => Dict(
                "carrier_in" => "oil",
                "carrier_out" => "gas",
            )
        )
    )

    @test Parse.parse_carriers(data["carriers"]) == Set(["gas", "oil"])
    
    # parse processes
    @test Parse.parse_processes(data["processes"], Set(["gas", "oil"])) == Dict(
        "gas_to_oil" => Dict("carrier_in" => "gas", "carrier_out" => "oil"),
        "oil_to_gas" => Dict("carrier_in" => "oil", "carrier_out" => "gas")
    )

    # carrier_in is not in carriers
    @test_throws Exception Parse.parse_processes(data["processes"], Set(["gas",]))
    
    # get_time_dependent
    @test Parse.get_time_dependent(1, [1,2,3,4,5,6], Int, dirname(@__FILE__)) == Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1, 6 => 1)
    @test Parse.get_time_dependent("./testdata/data_int.txt", [1,2,3,4,5,6], Int, dirname(@__FILE__)) == Dict(1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6)

    # linear interpolation
    peice_wise_data = [
        Dict("x" => 1, "y" => 1),
        Dict("x" => 1, "y" => 2),
        Dict("x" => 3, "y" => 3),
    ]
    @test_throws Parse.InvalidParameterError Parse.linear_interpolation(peice_wise_data, [0,1.2,3.4,5.6,8], Float64)
    peice_wise_data = [
        Dict("x" => 1, "y" => 1),
    ]
    @test_throws Parse.InvalidParameterError Parse.linear_interpolation(peice_wise_data, [0,1.2,3.4,5.6,8], Float64)
    peice_wise_data = [
        Dict("x" => 1, "y" => 1),
        Dict("x" => 2, "y" => 2),
        Dict("x" => 3, "y" => 3),
    ]
    @test Parse.linear_interpolation(peice_wise_data, [0,1.2,3.4,5.6,8], Float64) == [1.0, 1.2, 3, 3, 3]
    
    # get_year_dependent
    @test Parse.get_year_dependent(1, [1,2,3,4,5,6], Int) == Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1, 6 => 1)
    @test Parse.get_year_dependent(peice_wise_data, [0,1,2,3,4,5,6], Int) == Dict(0=>1, 1 => 1, 2 => 2, 3 => 3, 4 => 3, 5 => 3, 6 => 3)

    # parse parameters
    parameters = Dict(
        "param_scalar" => Dict(
            "comment" => "scalar parameter",
            "sets" => [],
            "defult" => 1, # misspelled
            "value" => 1,
            "type" => "Integer",
        ),
    )   
    @test_throws Parse.InvalidParameterError Parse.validate_parameters(parameters)
    parameters = Dict(
        "param_scalar" => Dict(
            "comment" => "scalar parameter",
            "sets" => [],
            "default" => 1, 
            "value" => 1, # sets is missing
        ),
    )
    @test_throws Parse.InvalidParameterError Parse.validate_parameters(parameters)
    parameters = Dict(
        "param_scalar" => Dict(
            "comment" => "scalar parameter",
            "sets" => [],
            "default" => 1,
            "value" => 1,
            "type" => "Int", # invalid type
        ),
    )
    @test_throws Parse.InvalidParameterError Parse.validate_parameters(parameters)
    parameters = Dict(
        "param_scalar" => Dict(
            "comment" => "scalar parameter",
            "sets" => ["S"], # invalid set name
            "default" => 1, 
            "value" => 1,
            "type" => "Integer",
        ),
    )
    @test_throws Parse.InvalidParameterError Parse.validate_parameters(parameters)
    parameters = Dict(
        "param_scalar" => Dict(
            "comment" => "scalar parameter",
            "sets" => ["P","Y","T"], # invalid sets combination
            "default" => 1, 
            "value" => 1,
            "type" => "Integer",
        ),
    )
    @test_throws Parse.InvalidParameterError Parse.validate_parameters(parameters)
        
    # test get_independent_parameters
    parameters = Dict(
        "param_scalar" => Dict(
            "comment" => "scalar parameter",
            "sets" => [],
            "default" => 1,
            "value" => 1,
            "type" => "Integer",
        ),
        "param_array" => Dict(
            "comment" => "array parameter",
            "sets" => ["Y"],
            "default" => 2.2,
            "value" => 1,
            "type" => "Float",
            "quantity" => "energy",
        ),
        "param_pw" => Dict(
            "comment" => "piecewise parameter",
            "sets" => ["Y"],
            "default" => 2.2,
            "value" => [
                Dict("x" => 2, "y" => 1),
                Dict("x" => 3, "y" => 2),
                Dict("x" => 4, "y" => 3),
            ],
            "type" => "Float",
        )
    )

    units = Dict(
        "energy" => Dict("input" => "TWh", "scale" => 12.0, "output" => "GWh"),
        "power" => Dict("input" => "GW", "scale" => 1.0, "output" => "GW"),
        "co2_emissions" => Dict("input" => "Mio t", "scale" => 1.0, "output" => "Mio t"),
    )
    @test Parse.get_independent_parameters(parameters, [1,2,3,4,5,6], units) == Dict(
        "defaults" => Dict("param_scalar" => 1, "param_array" => 2.2*12, "param_pw" => 2.2),
        "param_scalar" => 1,
        "param_array" => Dict(
            1 => 12.,
            2 => 12.,
            3 => 12.,
            4 => 12.,
            5 => 12.,
            6 => 12.,
        ),
        "param_pw" => Dict(
            1 => 1.,
            2 => 1.,
            3 => 2.,
            4 => 3.,
            5 => 3.,
            6 => 3.,
        ),
    )

    # test get_dependent_parameters
    parameters = Dict(
        "param_scalar_independent" => Dict(
            "comment" => "scalar parameter",
            "sets" => [],
            "default" => 1,
            "value" => 1,
            "type" => "Integer",
        ),
        "param_array" => Dict(
            "comment" => "array parameter",
            "sets" => ["Y"],
            "default" => 2.2,
            "value" => 1,
            "type" => "Float",
            "quantity" => "energy",
        ),
        "param_pw" => Dict(
            "comment" => "piecewise parameter",
            "sets" => ["Y"],
            "default" => 2.2,
            "value" => [
                Dict("x" => 2, "y" => 1),
                Dict("x" => 3, "y" => 2),
                Dict("x" => 4, "y" => 3),
            ],
            "type" => "Float",
        ),
        "param_scalar" => Dict(
            "comment" => "scalar parameter",
            "sets" => ["P"],
            "default" => 1,
            "type" => "Integer",
            "quantity" => "energy",
        ),
        "param_t" => Dict(
            "comment" => "array parameter",
            "sets" => ["P","T"],
            "default" => 2.2,
            "type" => "Float",
        ),
        "param_y" => Dict(
            "comment" => "piecewise parameter",
            "sets" => ["P","Y"],
            "default" => 2.2,
            "type" => "Float",
            "quantity" => "power",
        ),
        "param_c_color" => Dict(
            "comment" => "carrier color",
            "sets" => ["C"],
            "default" => "blue",
            "type" => "String",
        ),
    )
    carriers = Dict(
        "gas" => Dict(
            "comment" => "gas carrier",
            "parameters" => Dict(
                "param_c_color" => "orange",
            )
        ),
        "oil" => Dict(
            "comment" => "oil carrier",
            "parameters" => Dict(
            )
        )
    )

    processes = Dict(
        "gas_to_oil" => Dict(
            "carrier_in" => "gas",
            "carrier_out" => "oil",
            "parameters" => Dict(
                "param_scalar" => 1,
                "param_t" => 2.2,
                "param_y" => 2.3,
            )
        ),
        "oil_to_gas" => Dict(
            "carrier_in" => "oil",
            "carrier_out" => "gas",
            "parameters" => Dict(
                "param_t" => "./testdata/data_float.txt",
                "param_y" => [
                    Dict("x" => 2, "y" => 1),
                    Dict("x" => 3, "y" => 2),
                    Dict("x" => 4, "y" => 3),
                ],
            )
        )
    )

    years = [ 1,2,3,4,5,6]
    tss = [1,2,3,4,5,6]


    units = Dict(
        "energy" => Dict("input" => "TWh", "scale" => 12.0, "output" => "GWh"),
        "power" => Dict("input" => "GW", "scale" => 1.0, "output" => "GW"),
        "co2_emissions" => Dict("input" => "Mio t", "scale" => 1.0, "output" => "Mio t"),
    )

    @test Parse.get_dependent_parameters(parameters, processes, carriers, years, tss, units, dirname(@__FILE__)) == Dict(
        "param_scalar" => Dict(
            "gas_to_oil" => 12.0,
        ),
        "param_t" => Dict(
            "gas_to_oil" => Dict(
                1 => 2.2,
                2 => 2.2,
                3 => 2.2,
                4 => 2.2,
                5 => 2.2,
                6 => 2.2,
            ),
            "oil_to_gas" => Dict(
                1 => 1.,
                2 => 2.,
                3 => 3.,
                4 => 4.,
                5 => 5.2,
                6 => 6.7,
            )
        ),
        "param_y" => Dict(
            "gas_to_oil" => Dict(
                1 => 2.3,
                2 => 2.3,
                3 => 2.3,
                4 => 2.3,
                5 => 2.3,
                6 => 2.3,
            ),
            "oil_to_gas" => Dict(
                1 => 1.,
                2 => 1.,
                3 => 2.,
                4 => 3.,
                5 => 3.,
                6 => 3.,
            ),
        ),
        "param_c_color" => Dict(
            "gas" => "orange",
        ),
    )

    @test Parse.get_parameters(parameters, processes, carriers, years, tss, units, dirname(@__FILE__)) == Dict(
        "defaults" => Dict("param_scalar_independent" => 1, "param_scalar" => 12.0, "param_array" => 2.2*12, "param_pw" => 2.2, "param_t" => 2.2, "param_y" => 2.2, "param_c_color" => "blue"),
        "param_scalar_independent" => 1,
        "param_array" => Dict(
            1 => 12.,
            2 => 12.,
            3 => 12.,
            4 => 12.,
            5 => 12.,
            6 => 12.,
        ),
        "param_pw" => Dict(
            1 => 1.,
            2 => 1.,
            3 => 2.,
            4 => 3.,
            5 => 3.,
            6 => 3.,
        ),
        "param_scalar" => Dict(
            "gas_to_oil" => 12.0,
        ),
        "param_t" => Dict(
            "gas_to_oil" => Dict(
                1 => 2.2,
                2 => 2.2,
                3 => 2.2,
                4 => 2.2,
                5 => 2.2,
                6 => 2.2,
            ),
            "oil_to_gas" => Dict(
                1 => 1.,
                2 => 2.,
                3 => 3.,
                4 => 4.,
                5 => 5.2,
                6 => 6.7,
            )
        ),
        "param_y" => Dict(
            "gas_to_oil" => Dict(
                1 => 2.3,
                2 => 2.3,
                3 => 2.3,
                4 => 2.3,
                5 => 2.3,
                6 => 2.3,
            ),
            "oil_to_gas" => Dict(
                1 => 1.,
                2 => 1.,
                3 => 2.,
                4 => 3.,
                5 => 3.,
                6 => 3.,
            ),
        ),
        "param_c_color" => Dict(
            "gas" => "orange",
        ),
    )
    # PrettyPrinting.pprint(Parse.get_parameters(parameters, processes, carriers, years, tss, units, dirname(@__FILE__)))
    # PrettyPrinting.pprint(x)

end