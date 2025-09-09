module Components

export Carrier, Process, Region, Year, Unit, Time, Input, sina

struct Unit
    input::String
    output::String
    scale::Float64
end

struct Year
    value::Int
end

# Allow conversion to Int
Base.convert(::Type{Int}, y::Year) = y.value
Base.Int(y::Year) = y.value

# Arithmetic: Year + Int, Int + Year, Year + Year
Base.:+(y::Year, x::Integer) = Year(y.value + x)
Base.:+(x::Integer, y::Year) = Year(x + y.value)
Base.:+(a::Year, b::Year) = Year(a.value + b.value)

Base.:-(y::Year, x::Integer) = y.value - x
Base.:-(x::Integer, y::Year) = x - y.value
Base.:-(a::Year, b::Year) = a.value - b.value

# Comparisons
Base.:(==)(a::Year, b::Year) = a.value == b.value
Base.:<(a::Year, b::Year) = a.value < b.value
Base.:<=(a::Year, b::Year) = a.value <= b.value
Base.:>(a::Year, b::Year) = a.value > b.value
Base.:>=(a::Year, b::Year) = a.value >= b.value

# Show as an integer
Base.show(io::IO, y::Year) = print(io, y.value)


struct Time
    value::Int
end

# Allow conversion to Int
Base.convert(::Type{Int}, y::Time) = y.value
Base.Int(y::Time) = y.value

# Arithmetic: Time + Int, Int + Time, Time + Time
Base.:+(y::Time, x::Integer) = Time(y.value + x)
Base.:+(x::Integer, y::Time) = Time(x + y.value)
Base.:+(a::Time, b::Time) = Time(a.value + b.value)

Base.:-(y::Time, x::Integer) = Time(y.value - x)
Base.:-(x::Integer, y::Time) = Time(x - y.value)
Base.:-(a::Time, b::Time) = Time(a.value - b.value)

# Comparisons
Base.:(==)(a::Time, b::Time) = a.value == b.value
Base.:<(a::Time, b::Time) = a.value < b.value
Base.:<=(a::Time, b::Time) = a.value <= b.value
Base.:>(a::Time, b::Time) = a.value > b.value
Base.:>=(a::Time, b::Time) = a.value >= b.value

# Show as an integer
Base.show(io::IO, y::Time) = print(io, y.value)


struct Carrier
    name::String
end

Base.:(==)(c1::Carrier, c2::Carrier) = 
    c1.name == c2.name

struct Process
    name::String
    carrier_in::Carrier
    carrier_out::Carrier
end

Base.:(==)(p1::Process, p2::Process) =
    p1.name == p2.name

Base.convert(::Type{String}, p::Process) = "$(p.name)_$(p.carrier_in)_$(p.carrier_out)"
Base.String(p::Process) = "$(p.name)_$(p.carrier_in)_$(p.carrier_out)"

"""
    Input
    A struct to hold
"""
struct Input
    """
    A struct to hold
    """
    units::Dict{String, Unit}
    years::Vector{Year}
    timesteps::Vector{Time}
    carriers::Set{Carrier}
    processes::Set{Process}
    parameters::Dict{String, Any}
end

end


