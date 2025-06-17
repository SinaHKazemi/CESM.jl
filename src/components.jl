module Components

export Carrier, Process, Region, Year, Unit, Time, Input

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

struct Region
    name::String
end

# String conversion
Base.convert(::Type{String}, r::Region) = r.name
Base.String(r::Region) = r.name

# Show as a string
Base.show(io::IO, r::Region) = print(io, r.name)

# Comparison (region == string)
Base.:(==)(r::Region, s::String) = r.name == s
Base.:(==)(s::String, r::Region) = s == r.name
Base.:(==)(r1::Region, r2::Region) = r1.name == r2.name

struct Carrier
    name::String
    region::Region
end


Base.convert(::Type{String}, c::Carrier) = "$(c.name)_$(c.region)"
Base.String(c::Carrier) = "$(c.name)_$(c.region)"

Base.:(==)(c1::Carrier, c2::Carrier) = 
    c1.name == c2.name && c1.region == c2.region

struct Process
    name::String
    carrier_in::Carrier
    carrier_out::Carrier
end

Base.:(==)(p1::Process, p2::Process) =
    p1.name == p2.name &&
    p1.carrier_in == p2.carrier_in &&
    p1.carrier_out == p2.carrier_out

Base.convert(::Type{String}, p::Process) = "$(p.name)_$(p.carrier_in)_$(p.carrier_out)"
Base.String(p::Process) = "$(p.name)_$(p.carrier_in)_$(p.carrier_out)"


struct Input
    units::Dict{String, Unit}
    years::Vector{Year}
    timesteps::Vector{Time}
    regions::Set{Region}
    carriers::Set{Carrier}
    processes::Set{Process}
    parameters::Dict{String, Any}
end

end


