module Utils

using Logging, LoggingExtras
using SHA

export Setting, logfile_name, simple_file_logger


function pretty_print(io::IO, x)
    T = typeof(x)
    fields = fieldnames(T)
    values = [getfield(x, f) for f in fields]

    # Determine column width for alignment
    maxlen = maximum(length.(String.(fields)))

    println(io, "=== $(T) ===")
    for (f, v) in zip(fields, values)
        fname = String(f)
        padding = " " ^ (maxlen - length(fname))
        println(io, fname, padding, " : ", v)
    end
end

struct Setting
    config_file::String
    manipulation_bound::Float64 # 0.1
    manipulated_cp::String # "Battery"
    target_cp::String # "PP_Wind" it has to be a renwewable
    target_change::Float64 # 0.2
    init_mu::Float64 # 1.0
    init_trust_region_radius::Float64 # 0.05
    min_stationary_change::Float64 # 1e-4
    min_obj_improvement_rate::Float64 # 1e-2
    last_year::Int64 # 2050
    duality_gap_tolerance::Float64 # 1e-2
    max_outer_iterations::Int64
    max_inner_iterations::Int64
    log_folder_path::String
end

function Base.show(io::IO, s::Setting)
    pretty_print(io, s)
end

function Setting(; 
        config_file::String,
        manipulation_bound::Float64,
        manipulated_cp::String,
        target_cp::String,
        target_change::Float64,
        init_mu::Float64,
        init_trust_region_radius::Float64=0.05,
        min_stationary_change::Float64=1e-4,
        min_obj_improvement_rate::Float64=1e-2,
        last_year::Int64=typemax(Int),
        duality_gap_tolerance::Float64=1e-2,
        max_outer_iterations::Int64=40,
        max_inner_iterations::Int64=50,
        log_folder_path::String="."
    )
    
    if manipulation_bound < 0.0 || manipulation_bound > 1.0
        throw(ArgumentError("manipulation_bound must be between 0 and 1, got $manipulation_bound"))
    end

    return Setting(
        config_file,
        manipulation_bound,
        manipulated_cp,
        target_cp,
        target_change,
        init_mu,
        init_trust_region_radius,
        min_stationary_change,
        min_obj_improvement_rate,
        last_year,
        duality_gap_tolerance,
        max_outer_iterations,
        max_inner_iterations,
        log_folder_path
    )
end

function logfile_name(s::Setting)
    data = sprint(io -> show(io, s))
    h = bytes2hex(sha1(data))[1:10]  # shortened hash
    return "$(s.manipulated_cp)_$(s.target_cp)_$(h)"
end

function simple_file_logger(path::String)
    io = open(path, "w")
    return FormatLogger(io) do io, log
        # Print only: "Info: message"
        println(io, "$(log.level): ", log.message)

        # flush so logs appear immediately
        flush(io)
    end
end

end # module Utils