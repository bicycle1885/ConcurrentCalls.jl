# Trace for Profiling
# ===================

mutable struct Trace
    starttime::Nullable{DateTime}
    snapshots::Vector{Tuple{UInt64,Stats}}

    function Trace()
        return new(nothing, [])
    end
end

function takesnapshot!(trace, stats)
    t = time_ns()
    if isempty(trace.snapshots)
        trace.starttime = now()
    end
    push!(trace.snapshots, (t, deepcopy(stats)))
    return trace
end

function elapsedtime(trace)
    if isempty(trace.snapshots)
        return typemax(UInt64)
    else
        return time_ns() - trace.snapshots[end][1]
    end
end

function Base.print(io::IO, trace::Trace)
    join(io,
         (:snapshot,
          :datetime,
          :calltime_ns,
          :selecttime_ns,
          :remotecalltime_ns,
          :waitargstime_ns), '\t')
    if isempty(trace.snapshots)
        return
    end
    starttime = get(trace.starttime)
    starttime_ns, _ = trace.snapshots[1]
    for i in 1:endof(trace.snapshots)
        println(io)
        time_ns, stats = trace.snapshots[i]
        datetime = starttime + Dates.Nanosecond(time_ns - starttime_ns)
        join(io,
             (i,
              datetime,
              stats.calltime_ns,
              stats.selecttime_ns,
              stats.remotecalltime_ns,
              stats.waitargstime_ns), '\t')
    end
end
