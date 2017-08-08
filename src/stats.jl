# Statistics
# ==========

mutable struct WorkerStats
    # the number of calls emitted
    ncalls::Int

    # the number of calls finished
    nfinished::Int

    function WorkerStats()
        return new(0, 0)
    end
end

mutable struct Stats
    # statistics state {:uninitialized, :initialized, :finalized}
    state::Symbol

    # the number of workers
    nworkers::Int

    # stats of each worker
    workerstats::Dict{Int,WorkerStats}

    # initialized time
    inittime::DateTime

    # initialized time (nano second)
    inittime_ns::UInt64

    # finalized time (nano second)
    fintime_ns::UInt64

    # total call time (nano second)
    calltime_ns::UInt64

    # total worker select time (nano second)
    selecttime_ns::UInt64

    # total remotecall time (nano second)
    remotecalltime_ns::UInt64

    # total waitargs time (nano second)
    waitargstime_ns::UInt64

    # teardown time (nano second)
    teardowntime_ns::UInt64

    function Stats()
        return new(
            :uninitialized, 0, Dict{Int,WorkerStats}(),
            DateTime(), 0, 0, 0, 0, 0, 0, 0)
    end
end

function Base.show(io::IO, stats::Stats)
    println(io, "Statistics:")
    println(io, "  state=$(stats.state)")
    if stats.state == :uninitialized
        return
    end
    println(io, "  nworkers=$(stats.nworkers)")
    println(io, "  worker stats:")
    for worker in sort!(collect(keys(stats.workerstats)))
        workerstats = stats.workerstats[worker]
        println(io, "    worker=$(worker) ncalls=$(workerstats.ncalls) nfinished=$(workerstats.nfinished)")
    end
    println(io, "  initialization: ", stats.inittime)
    if stats.state == :finalized
        total = stats.fintime_ns - stats.inittime_ns
        println(io, "  total time:   $(readable_time(total)) (100.00%)")
        println(io, "    call:       $(readable_time(stats.calltime_ns)) ($(readable_ratio(stats.calltime_ns, total)))")
        println(io, "    select:     $(readable_time(stats.selecttime_ns)) ($(readable_ratio(stats.selecttime_ns, total)))")
        println(io, "    remotecall: $(readable_time(stats.remotecalltime_ns)) ($(readable_ratio(stats.remotecalltime_ns, total)))")
        println(io, "    waitargs:   $(readable_time(stats.waitargstime_ns)) ($(readable_ratio(stats.waitargstime_ns, total)))")
        println(io, "    teardown:   $(readable_time(stats.teardowntime_ns)) ($(readable_ratio(stats.teardowntime_ns, total)))")
    end
end

function readable_time(ns)
    scale = 9
    for unit in ["s", "ms", "μs"]
        if ns ≥ 10^scale
            return @sprintf("%.2f%s", ns / 10^scale, unit)
        end
        scale -= 3
    end
    return @sprintf("%.2fns", ns)
end

function readable_ratio(num, den)
    return @sprintf("%.2f%%", num / den * 100)
end

function initstats!(stats, workers)
    stats.inittime = now()
    stats.inittime_ns = time_ns()
    stats.nworkers = length(workers)
    for worker in workers
        stats.workerstats[worker] = WorkerStats()
    end
    stats.state = :initialized
    return stats
end

function finstats!(stats)
    stats.fintime_ns = time_ns()
    stats.state = :finalized
    return stats
end

macro tic()
    quote
        __start__ = time_ns()
    end |> esc
end

macro toc(metric)
    quote
        $(metric) += time_ns() - __start__
    end |> esc
end
