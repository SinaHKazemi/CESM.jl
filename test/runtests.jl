using Test
using Revise


include("../src/CESM.jl")

import CESM.Parse as Parse
using CESM.Components

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


    # parse data file
    @test Parse.parse_data_file("./testdata/data_int.txt", dirname(@__FILE__), Int) == [1,2,3,4,5,6]  # Expected output is just a printed message
    @test Parse.parse_data_file("./testdata/data_float.txt", dirname(@__FILE__), Float64) == [1,2,3,4,5.2,6.7]  # Expected output is just a printed message
    # get_vector_or_file
    @test Parse.get_vector_or_file([1,2,3,4,5,6], Int, dirname(@__FILE__)) == [1,2,3,4,5,6]
    @test Parse.get_vector_or_file("./testdata/data_int.txt", Int, dirname(@__FILE__)) == [1,2,3,4,5,6]
    # validate_temporal_sequence
    @test_throws Parse.TemporalSequenceError Parse.validate_temporal_sequence([1,2,3,4,6,5])
    @test_throws Parse.TemporalSequenceError Parse.validate_temporal_sequence([-1,0,1,2,3])
    # parse_timesteps
    @test Parse.parse_timesteps([1,2,3,4,5,6], dirname(@__FILE__)) == [Time(t) for t in 1:6]
    # parse_years
    @test Parse.parse_years([1,2,3,4,5,6], dirname(@__FILE__)) == [Year(y) for y in 1:6]
    # parse carriers

    # parse regions
    regions_json = [
        "Hessen",
        "Berlin",
        "Baden-Württemberg",
    ]
    regions = Set([Region("Hessen"), Region("Berlin"), Region("Baden-Württemberg")])
    
    @test Parse.parse_regions(regions_json) == regions

    # parse_carriers
    carriers_json = [
        Dict(
            "name" => "gas",
            "region" => "Hessen",
        ),
        Dict(
            "name" => "oil",
            "region" => "Berlin",
        ),
        Dict(
            "name" => "gas",
            "region" => "Baden-Württemberg",
        )
    ]
    carriers = Set([
        Carrier("gas", Region("Hessen")),
        Carrier("oil", Region("Berlin")),
        Carrier("gas", Region("Baden-Württemberg")),
    ])

    @test Parse.parse_carriers(carriers_json, regions) == carriers

    # parse processes

    processes_json = [
        Dict(
            "name" => "gas_to_oil",
            "carrier_in" => Dict("name" => "gas", "region" => "Hessen"),
            "carrier_out" => Dict("name" => "oil", "region" => "Berlin")
        ),
        Dict(
            "name" => "oil_to_gas",
            "carrier_in" => Dict("name" => "oil", "region" => "Berlin"),
            "carrier_out" => Dict("name" => "gas", "region" => "Baden-Württemberg")
        )
    ]
    
    processes = Set([
        Process("gas_to_oil", Carrier("gas", Region("Hessen")), Carrier("oil", Region("Berlin"))),
        Process("oil_to_gas", Carrier("oil", Region("Berlin")), Carrier("gas", Region("Baden-Württemberg")))
    ])
    @test Parse.parse_processes(processes_json, carriers) == processes

    # carrier_in is not in carriers
    
    
    # get_time_dependent
    @test Parse.get_time_dependent(1, [Time(t) for t in 1:6], Int, dirname(@__FILE__)) == Dict(Time(i) => 1 for i in 1:6)
    @test Parse.get_time_dependent("./testdata/data_int.txt", [Time(t) for t in 1:6], Int, dirname(@__FILE__)) == Dict(Time(i) => i for i in 1:6)

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
    @test Parse.get_year_dependent(1, [Year(y) for y in 1:6], Int) == Dict(Year(i) => 1 for i in 1:6)
    @test Parse.get_year_dependent(peice_wise_data, [Year(y) for y in 1:6], Int) == Dict(Year(1) => 1, Year(2) => 2, Year(3) => 3, Year(4) => 3, Year(5) => 3, Year(6) => 3)
    # Dict(0=>1, 1 => 1, 2 => 2, 3 => 3, 4 => 3, 5 => 3, 6 => 3)

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

    units_json = Dict(
        "energy" => Dict("input" => "TWh", "scale" => 12.0, "output" => "GWh"),
        "power" => Dict("input" => "GW", "scale" => 1.0, "output" => "GW"),
        "co2_emissions" => Dict("input" => "Mio t", "scale" => 1.0, "output" => "Mio t"),
    )
    
    units = Dict(
        "energy" => Components.Unit("TWh", "GWh", 12.0),
        "power" => Components.Unit("GW", "GW", 1.0),
        "co2_emissions" => Components.Unit("Mio t", "Mio t", 1.0),
    )

    @test Parse.get_units(units_json) == units

    @test Parse.get_independent_parameters(parameters, [Year(y) for y in 1:6], units) == Dict(
        "defaults" => Dict("param_scalar" => 1, "param_array" => 2.2*12, "param_pw" => 2.2),
        "param_scalar" => 1,
        "param_array" => Dict(Year(i) => 12. for i in 1:6),
        "param_pw" => Dict(
            Year(1) => 1.,
            Year(2) => 1.,
            Year(3) => 2.,
            Year(4) => 3.,
            Year(5) => 3.,
            Year(6) => 3.,
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
    carriers_json = [
        Dict(
            "name" => "gas",
            "region" => "Hessen",
            "parameters" => Dict(
                "param_c_color" => "orange",
            ),
            "struct" => Carrier("gas", Region("Hessen"))
        ),
        Dict(
            "name" => "oil",
            "region" => "Berlin",
            "struct" => Carrier("oil", Region("Berlin"))
        ),
        Dict(
            "name" => "gas",
            "region" => "Baden-Württemberg",
            "struct" => Carrier("gas", Region("Baden-Württemberg"))
        )
    ]

    processes_json = [
        Dict(
            "name" => "gas_to_oil",
            "carrier_in" => Dict("name" => "gas", "region" => "Hessen"),
            "carrier_out" => Dict("name" => "oil", "region" => "Berlin"),
            "parameters" => Dict(
                "param_scalar" => 1,
                "param_t" => 2.2,
                "param_y" => 2.3,
            ),
            "struct" => Process("gas_to_oil", Carrier("gas", Region("Hessen")), Carrier("oil", Region("Berlin"))),
        ),
        Dict(
            "name" => "oil_to_gas",
            "carrier_in" => Dict("name" => "oil", "region" => "Berlin"),
            "carrier_out" => Dict("name" => "gas", "region" => "Baden-Württemberg"),
            "parameters" => Dict(
                "param_t" => "./testdata/data_float.txt",
                "param_y" => [
                    Dict("x" => 2, "y" => 1),
                    Dict("x" => 3, "y" => 2),
                    Dict("x" => 4, "y" => 3),
                ],
            ),
            "struct" => Process("oil_to_gas", Carrier("oil", Region("Berlin")), Carrier("gas", Region("Baden-Württemberg")))
        )
    ]

    years = [Year(y) for y in 1:6]
    timesteps = [Time(t) for t in 1:6]


    @test Parse.get_dependent_parameters(parameters, processes_json, carriers_json, years, timesteps, units, dirname(@__FILE__)) == Dict(
        "param_scalar" => Dict(
            Process("gas_to_oil", Carrier("gas", Region("Hessen")), Carrier("oil", Region("Berlin"))) => 12.0,
        ),
        "param_t" => Dict(
            Process("gas_to_oil", Carrier("gas", Region("Hessen")), Carrier("oil", Region("Berlin"))) => Dict(
                Time(1) => 2.2,
                Time(2) => 2.2,
                Time(3) => 2.2,
                Time(4) => 2.2,
                Time(5) => 2.2,
                Time(6) => 2.2,
            ),
            Process("oil_to_gas", Carrier("oil", Region("Berlin")), Carrier("gas", Region("Baden-Württemberg"))) => Dict(
                Time(1) => 1.,
                Time(2) => 2.,
                Time(3) => 3.,
                Time(4) => 4.,
                Time(5) => 5.2,
                Time(6) => 6.7,
            )
        ),
        "param_y" => Dict(
            Process("gas_to_oil", Carrier("gas", Region("Hessen")), Carrier("oil", Region("Berlin"))) => Dict(
                Year(1) => 2.3,
                Year(2) => 2.3,
                Year(3) => 2.3,
                Year(4) => 2.3,
                Year(5) => 2.3,
                Year(6) => 2.3,
            ),
            Process("oil_to_gas", Carrier("oil", Region("Berlin")), Carrier("gas", Region("Baden-Württemberg"))) => Dict(
                Year(1) => 1.,
                Year(2) => 1.,
                Year(3) => 2.,
                Year(4) => 3.,
                Year(5) => 3.,
                Year(6) => 3.,
            ),
        ),
        "param_c_color" => Dict(
            Carrier("gas", Region("Hessen")) => "orange",
        ),
    )

    @test Parse.get_parameters(parameters, processes_json, carriers_json, years, timesteps, units, dirname(@__FILE__)) == Dict(
        "defaults" => Dict("param_scalar_independent" => 1, "param_scalar" => 12.0, "param_array" => 2.2*12, "param_pw" => 2.2, "param_t" => 2.2, "param_y" => 2.2, "param_c_color" => "blue"),
        "param_scalar_independent" => 1,
        "param_array" => Dict(
            Year(1) => 12.,
            Year(2) => 12.,
            Year(3) => 12.,
            Year(4) => 12.,
            Year(5) => 12.,
            Year(6) => 12.,
        ),
        "param_pw" => Dict(
            Year(1) => 1.,
            Year(2) => 1.,
            Year(3) => 2.,
            Year(4) => 3.,
            Year(5) => 3.,
            Year(6) => 3.,
        ),
        "param_scalar" => Dict(
            Process("gas_to_oil", Carrier("gas", Region("Hessen")), Carrier("oil", Region("Berlin"))) => 12.0,
        ),
        "param_t" => Dict(
            Process("gas_to_oil", Carrier("gas", Region("Hessen")), Carrier("oil", Region("Berlin"))) => Dict(
                Time(1) => 2.2,
                Time(2) => 2.2,
                Time(3) => 2.2,
                Time(4) => 2.2,
                Time(5) => 2.2,
                Time(6) => 2.2,
            ),
            Process("oil_to_gas", Carrier("oil", Region("Berlin")), Carrier("gas", Region("Baden-Württemberg"))) => Dict(
                Time(1) => 1.,
                Time(2) => 2.,
                Time(3) => 3.,
                Time(4) => 4.,
                Time(5) => 5.2,
                Time(6) => 6.7,
            )
        ),
        "param_y" => Dict(
            Process("gas_to_oil", Carrier("gas", Region("Hessen")), Carrier("oil", Region("Berlin"))) => Dict(
                Year(1) => 2.3,
                Year(2) => 2.3,
                Year(3) => 2.3,
                Year(4) => 2.3,
                Year(5) => 2.3,
                Year(6) => 2.3,
            ),
            Process("oil_to_gas", Carrier("oil", Region("Berlin")), Carrier("gas", Region("Baden-Württemberg"))) => Dict(
                Year(1) => 1.,
                Year(2) => 1.,
                Year(3) => 2.,
                Year(4) => 3.,
                Year(5) => 3.,
                Year(6) => 3.,
            ),
        ),
        "param_c_color" => Dict(
            Carrier("gas", Region("Hessen")) => "orange",
        ),
    )

end