push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using Documenter, CESM, DocumenterMermaid

makedocs(
    format = Documenter.HTML(),
    sitename="CESM.jl",
    pages = [
        "index.md",
        "Model" => "model.md",
        "Config File" => "config.md",
        "Input and Output" => "inout.md",
        "Variables" => "variables.md",
        "API" => "api.md",
        "Subsection" => [
            "sub1" => "sub/sub1.md",
            "Subsection 2" => "sub/sub2.md"
        ]
    ],
)


deploydocs(
    repo = "https://github.com/SinaHKazemi/CESM.jl.git",
    branch = "gh-pages"
)