# Scheduler
# =========

struct Scheduler
    # global configuration
    config::Config

    # runtime statistics
    stats::Stats

    # trace for profiling
    trace::Trace

    # immediately available workers
    availworkers::Vector{Int}

    # waiting remote calls (key: worker, value: set of remote calls)
    waitcalls::Dict{Int,Set{Task}}

    # futures associated with remote calls
    futures::WeakKeyDict{Task,Future}

    # remote functions
    remotefuncs::Dict{Function,Dict{Int,RemoteChannel}}

    function Scheduler(config::Config)
        stats = Stats()
        workers = Int[]
        waitcalls = Dict{Int,Set{Task}}()
        for worker in config.workers
            for _ in 1:config.multiplicity
                push!(workers, worker)
            end
            waitcalls[worker] = Set{Task}()
        end
        scheduler = new(
            config, stats, Trace(),
            workers, waitcalls,
            WeakKeyDict{Task,Future}(), Dict())
        initstats!(stats, config.workers)
        return scheduler
    end
end

function Scheduler(workers::Vector{Int}=Base.workers())
    return Scheduler(Config(workers))
end

function teardown(scheduler)
    @tic
    for waitcalls in values(scheduler.waitcalls)
        while !isempty(waitcalls)
            wait(pop!(waitcalls))
        end
    end
    @toc scheduler.stats.teardowntime_ns
    finstats!(scheduler.stats)
    if scheduler.config.show_stats
        println(scheduler.config.output, sprint(show, scheduler.stats))
    end
    if scheduler.config.show_trace
        println(scheduler.config.output, scheduler.trace)
    end
    return nothing
end

function scoreworker(worker, scheduler, args)
    score = 0
    for arg in args
        if arg isa Future && arg.where == worker
            # data locality
            score += 1
        end
    end
    score -= length(scheduler.waitcalls[worker])
    return score
end

function selectworker(scheduler, args)
    @tic
    worker = 0
    while worker == 0
        while isempty(scheduler.availworkers)
            yield()
        end
        bestscore = typemin(Int)
        for w in scheduler.availworkers
            s = scoreworker(w, scheduler, args)
            if s > bestscore
                worker = w
                bestscore = s
            end
        end
    end
    @toc scheduler.stats.selecttime_ns
    return worker
end

function waitargs(args, stats)
    @tic
    newargs = map(a -> a isa RemoteCall ? wait(a) : a, args)
    @toc stats.waitargstime_ns
    return newargs
end

function waitarg(arg)
    if arg isa RemoteCall
        # Future
        return wait(arg)
    else
        return arg
    end
end

function call(scheduler, func, args...)
    @tic
    if elapsedtime(scheduler.trace) ≥ snapshot_interval(scheduler.config)
        takesnapshot!(scheduler.trace, scheduler.stats)
    end
    remotefunc = args -> func(map(fetch, args)...)
    if !haskey(scheduler.remotefuncs, remotefunc)
        scheduler.remotefuncs[remotefunc] = Dict{Int,RemoteChannel}()
    end
    while isempty(scheduler.availworkers)
        yield()
    end
    call = @task begin
        args = waitargs(args, scheduler.stats)
        worker = selectworker(scheduler, args)
        deleteat!(scheduler.availworkers, findfirst(scheduler.availworkers, worker))
        remotefuncs = scheduler.remotefuncs[remotefunc]
        cache = get!(remotefuncs, worker) do
            cache = RemoteChannel(worker)
            remotefuncs[worker] = cache
            put!(cache, remotefunc)
            cache
        end
        scheduler.stats.workerstats[worker].ncalls += 1
        call = current_task()
        waitcalls = scheduler.waitcalls[worker]
        push!(waitcalls, call)
        @tic
        future = remotecall_wait(args -> fetch(cache)(args), worker, args)
        @toc scheduler.stats.remotecalltime_ns
        scheduler.futures[call] = future
        delete!(waitcalls, call)
        push!(scheduler.availworkers, worker)
        future  # result
    end
    yield(call)
    @toc scheduler.stats.calltime_ns
    return RemoteCall(call)
end

function pmap(scheduler, func, iter)
    return [call(scheduler, func, item) for item in iter]
end
