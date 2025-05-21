using StaticArrays
# using Dictionaries

module Components

    export Input

    struct Region
        name::String
    end

    struct CO
        name::String
        region::Region
    end

    struct CP
        name::String
        cin::CO
        cout::CO
    end

    struct Time
        value::Int
    end

    struct Year
        value::Int
    end

    struct Plot
        cp::Dict{CP,Style}
        co::Dict{CO,Style} 
    end

    struct Style
        color::Symbol
        order::Int
    end

    struct Sets
        cp::SVector{CP}
        co::SVector{CO}
        region::SVector{Region}
        time::SVector{Time}
        year::SVector{Year}
    end

    struct Params
        scalar::Dict{Symbol,Number}
        y::Dict{Symbol,Dict{Year, Number}}
        cp::Dict{Symbol,Dict{CP, Number}}
        cp_y::Dict{Symbol,Dict{Tuple{CP,Year}, Number}}
        cp_t::Dict{Symbol,Dict{Tuple{CP,Time}, Number}}
    end

    struct Input
        sets::Sets
        params::Params
        plot::Plot
        units::Dict{Symbol,Unit}
    end

    struct Unit
        name::Symbol
        input::Symbol
        output::Symbol
        scale::Float64
    end

end