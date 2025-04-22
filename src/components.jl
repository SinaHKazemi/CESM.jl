struct CO
    name::Symbol
end

struct CP
    name::Symbol
    cin::CO
    cout::CO
end

struct Time
    value::Int
end

struct Year
    value::Int
end

struct Region
    name::Symbol
end

struct PlotStyle
    color::Symbol
    order::Int
end

function Base.show(io::IO, ::MIME"text/plain", p::MyParam)
    print(io, "MyParam(name=$(p.name), value=$(p.value))")
end
