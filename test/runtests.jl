using Test
include("../src/parser.jl")

@testset "MyPackage Tests" begin
    @test Parse.parse_data_file("./data.txt", dirname(@__FILE__) ,Int) == [1,2,3,4]  # Expected output is just a printed message
end