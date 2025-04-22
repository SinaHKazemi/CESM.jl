using StaticArrays
# using Dictionaries

module Components

    export Input

    struct Region
        name::Symbol
    end

    struct CO
        name::Symbol
        region::Region
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

    struct Plot
        cp::ImmutableDict{CP,Style}
        co::ImmutableDict{CO,Style} 
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
        scalar::ImmutableDict{Symbol,Number}
        y::ImmutableDict{Symbol,ImmutableDict{Year, Number}}
        cp::ImmutableDict{Symbol,ImmutableDict{CP, Number}}
        cp_y::ImmutableDict{Symbol,ImmutableDict{Tuple{CP,Year}, Number}}
        cp_t::ImmutableDict{Symbol,ImmutableDict{Tuple{CP,Time}, Number}}
    end

    struct Input
        sets::Sets
        params::Params
        plot::Plot
    end

end