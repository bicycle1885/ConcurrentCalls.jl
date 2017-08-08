# Configuration
# =============

struct Config
    # worker IDs
    workers::Vector{Int}

    # remotecall multiplicity per worker
    multiplicity::Int

    # maximum chunk size for parallel map
    chunksize::Int

    # minimum snapshot interval
    snapshot_interval::UInt64

    # show runtime statistics at last
    show_stats::Bool

    # show runtime trace at last
    show_trace::Bool

    # output of debug info (stats, trace, etc.)
    output::IO
end

function Config(workers;
                multiplicity::Integer=2,
                chunksize::Integer=64,
                snapshot_interval::Integer=10^9,
                show_stats::Bool=false,
                show_trace::Bool=false,
                output::IO=STDERR)
    return Config(
        workers, multiplicity, chunksize,
        snapshot_interval, show_stats, show_trace,
        output)
end

function chunksize(config::Config)
    return config.chunksize
end

function nworkers(config::Config)
    return length(config.workers)
end

function snapshot_interval(config::Config)
    return config.snapshot_interval
end
