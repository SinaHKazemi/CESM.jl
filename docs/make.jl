push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using Documenter, CESM, DocumenterMermaid

makedocs(
    format = Documenter.HTML(),
    sitename="CESM.jl",
    pages = [
        "index.md",
        "Reference" => [
            "Model" => "reference/model.md",
            "Config File" => "reference/config.md",
            "Input and Output" => "reference/inout.md",
            "Variables" => "reference/variables.md",
            "API" => "reference/api.md",
        ],
        "Tutorials" => [
            "sub1" => "tutorials/sub1.md",
            "Subsection 2" => "tutorials/sub2.md"
        ]
    ],
)


deploydocs(
    repo = "https://github.com/SinaHKazemi/CESM.jl.git",
    branch = "gh-pages"
)