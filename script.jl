# using CSV, DataFrames, XLSX

# Folder containing text files
# folder_path = "C:/Users/Sina Hajikazemi/Documents/mycode/CESM/Data/TimeSeries"  # Change to your folder path
# excel_file = "./data/DEModel.xlsx"  # Existing Excel file
# sheet_name = "TimeSeries2"  # Existing sheet name

# # Get all .txt files in the folder
# files = filter(f -> endswith(f, ".txt"), readdir(folder_path))
# print(typeof(files))
# # Open the existing Excel file in read-write mode
# XLSX.openxlsx(excel_file, mode="rw") do xf
#     # Iterate through each file and create a new sheet
#     for file in files
#         file_path = joinpath(folder_path, file)
#         sheet_name = splitext(file)[1]  # Use filename (without extension) as sheet name
        
#         # Read space-separated numbers into a DataFrame
#         df = DataFrame(CSV.File(file_path; delim=' ', header=false))

#         # Find the maximum length of the columns in the current file
#         # max_length = length(df)

#         # # Ensure all columns are of the same length, fill with missing if necessary
#         # df = DataFrame(hcat([vcat(col, fill(missing, max_length - length(col))) for col in eachcol(df)]))
#         # println(typeof(eachcol(df)))
#         vectors = [Float64(col[1]) for col in eachcol(df) if !ismissing(col[1])]
#         println(typeof(vectors))
#         # Create a new sheet and write the data
#         sheet = XLSX.addsheet!(xf, length(file)< 30 ? file : file[1:30])   # Create a new sheet
#         # df_transformed = DataFrame(Value = vectors)  # Transpose the Value column
#         # names!(df_transformed, df.Name)
#         # sheet = xf["sina"]
#         sheet["A1", dim=1] = vectors
#         # XLSX.writetable!(sheet, df)
#     end
# end

include("src/parser.jl")
include("src/model.jl")
using .Parse
using .Model

input = Parse.parse("data/DEModel.xlsx", "Base")
# println(input[:sets][:CP])
# println(sum(values(input[:params][:availability_profile][:PP_PV_Res])))
# println(input[:params][:availability_profile][:PP_WindOff_New])
# println(sum(values(input[:params][:output_profile][:Demand_Decentral_Heat])))
# println(input[:params][:cap_res_max][:Decentral_Heat_Pump])
# println(input[:params][:cap_max][:Decentral_Heat_Pump])

Model.run_cesm(input)