using ConcurrentCalls

const RemoteCall = ConcurrentCalls.RemoteCall

function report(title, ns, ncalls, stats)
    ns_per_call = ns / ncalls
    scale = 9
    for unit in ["s", "ms", "μs", "ns"]
        if ns_per_call ≥ 10^scale || scale == 0
            t = ns_per_call / 10^scale
            @printf("- %s:\t%.1f %s/call (%d workers, %d calls)\n", title, t, unit, stats.nworkers, ncalls)
            break
        end
        scale -= 3
    end
    if !isempty(get(ENV, "VERBOSE", ""))
        println()
        println(indent(sprint(show, stats); depth=6))
    end
end

function indent(text; depth=4)
    return join((string(" "^depth, line) for line in split(text, "\n")), "\n")
end

println("# Benchmark Report\n")

datetime_start = now()

let
    println("## Extremely lightweight task\n")
    N = 10_000
    workers = Base.workers()

    # warm-up
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, +, 1)
    b = ConcurrentCalls.call(scheduler, +, 1)
    c = ConcurrentCalls.call(scheduler, +, a, b)
    ConcurrentCalls.teardown(scheduler)
    @assert fetch(c) == 2

    # independent
    scheduler = ConcurrentCalls.Scheduler(workers)
    start = time_ns()
    for _ in 1:N
        ConcurrentCalls.call(scheduler, +, 0, 0)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    report("independent", ns, N, scheduler.stats)

    # sequential
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, +, 0, 0)
    start = time_ns()
    for _ in 1:N
        a = ConcurrentCalls.call(scheduler, +, a, 1)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(a) == N
    report("sequential", ns, N, scheduler.stats)

    # biparallel
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, +, 0, 0)
    b = ConcurrentCalls.call(scheduler, +, 0, 0)
    start = time_ns()
    for _ in 1:N
        a = ConcurrentCalls.call(scheduler, +, a, 1)
        b = ConcurrentCalls.call(scheduler, +, b, 1)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(a) == fetch(b) == N
    report("biparallel", ns, N * 2, scheduler.stats)

    # triparallel
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, +, 0, 0)
    b = ConcurrentCalls.call(scheduler, +, 0, 0)
    c = ConcurrentCalls.call(scheduler, +, 0, 0)
    start = time_ns()
    for _ in 1:N
        a = ConcurrentCalls.call(scheduler, +, a, 1)
        b = ConcurrentCalls.call(scheduler, +, b, 1)
        c = ConcurrentCalls.call(scheduler, +, c, 1)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(a) == fetch(b) == fetch(c) == N
    report("triparallel", ns, N * 3, scheduler.stats)

    # fan-in
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = Vector{RemoteCall}(N)
    start = time_ns()
    for i in 1:N
        a[i] = ConcurrentCalls.call(scheduler, +, 0, 1)
    end
    b = ConcurrentCalls.call(scheduler, +, a...)
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(b) == N
    report("fan-in", ns, N + 1, scheduler.stats)

    # fan-out
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, +, 0, 0)
    b = Vector{RemoteCall}(N)
    start = time_ns()
    for i in 1:N
        b[i] = ConcurrentCalls.call(scheduler, +, a, 1)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert all(fetch(b[i]) == 1 for i in 1:N)
    report("fan-out", ns, N, scheduler.stats)

    # pmap
    #=
    scheduler = ConcurrentCalls.Scheduler(workers)
    start = time_ns()
    a = ConcurrentCalls.pmap(scheduler, +, 1:N)
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert all(fetch(a[i]) == i for i in 1:N)
    report("pmap", ns, N, scheduler.stats)
    =#

    println()
end

let
    println("## 10ms sleep\n")
    N = 1000
    workers = Base.workers()

    function sleep(args...)
        Base.sleep(0.01)
    end

    # warm-up
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, sleep)
    b = ConcurrentCalls.call(scheduler, sleep, a)
    c = ConcurrentCalls.call(scheduler, sleep, b)
    ConcurrentCalls.teardown(scheduler)
    @assert fetch(c) === nothing

    # independent
    scheduler = ConcurrentCalls.Scheduler(workers)
    start = time_ns()
    for _ in 1:N
        ConcurrentCalls.call(scheduler, sleep)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    report("independent", ns, N, scheduler.stats)

    # sequential
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, sleep)
    start = time_ns()
    for _ in 1:N
        a = ConcurrentCalls.call(scheduler, sleep, a)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(a) === nothing
    report("sequential", ns, N, scheduler.stats)

    # biparallel
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, sleep)
    b = ConcurrentCalls.call(scheduler, sleep)
    start = time_ns()
    for _ in 1:N
        a = ConcurrentCalls.call(scheduler, sleep, a)
        b = ConcurrentCalls.call(scheduler, sleep, b)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(a) === fetch(b) === nothing
    report("biparallel", ns, N * 2, scheduler.stats)

    # triparallel
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, sleep)
    b = ConcurrentCalls.call(scheduler, sleep)
    c = ConcurrentCalls.call(scheduler, sleep)
    start = time_ns()
    for _ in 1:N
        a = ConcurrentCalls.call(scheduler, sleep, a)
        b = ConcurrentCalls.call(scheduler, sleep, b)
        c = ConcurrentCalls.call(scheduler, sleep, c)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(a) === fetch(b) === fetch(c) === nothing
    report("triparallel", ns, N * 3, scheduler.stats)

    # fan-in
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = Vector{RemoteCall}(N)
    start = time_ns()
    for i in 1:N
        a[i] = ConcurrentCalls.call(scheduler, sleep)
    end
    b = ConcurrentCalls.call(scheduler, sleep, a...)
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(b) === nothing
    report("fan-in", ns, N + 1, scheduler.stats)

    # fan-out
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, sleep)
    b = Vector{RemoteCall}(N)
    start = time_ns()
    for i in 1:N
        b[i] = ConcurrentCalls.call(scheduler, sleep, a)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert all(fetch(b[i]) === nothing for i in 1:N)
    report("fan-out", ns, N, scheduler.stats)

    # pmap
    #=
    scheduler = ConcurrentCalls.Scheduler(workers)
    start = time_ns()
    a = ConcurrentCalls.pmap(scheduler, sleep, 1:N)
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert all(fetch(a[i]) === nothing for i in 1:N)
    report("pmap", ns, N, scheduler.stats)
    =#

    println()
end

let
    println("## Large closure\n")
    N = 1000
    workers = Base.workers()

    array = zeros(1_000_000)

    function add(args...)
        return sum(array) + sum(args)
    end

    # warm-up
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, add, 0)
    b = ConcurrentCalls.call(scheduler, add, a)
    c = ConcurrentCalls.call(scheduler, add, b)
    ConcurrentCalls.teardown(scheduler)
    @assert fetch(c) == 0

    # independent
    scheduler = ConcurrentCalls.Scheduler(workers)
    start = time_ns()
    for _ in 1:N
        ConcurrentCalls.call(scheduler, add, 0)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    report("independent", ns, N, scheduler.stats)

    # sequential
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, add, 0)
    start = time_ns()
    for _ in 1:N
        a = ConcurrentCalls.call(scheduler, add, a)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(a) == 0
    report("sequential", ns, N, scheduler.stats)

    # biparallel
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, add, 0)
    b = ConcurrentCalls.call(scheduler, add, 0)
    start = time_ns()
    for _ in 1:N
        a = ConcurrentCalls.call(scheduler, add, a)
        b = ConcurrentCalls.call(scheduler, add, b)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(a) == fetch(b) == 0
    report("biparallel", ns, N * 2, scheduler.stats)

    # triparallel
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, add, 0)
    b = ConcurrentCalls.call(scheduler, add, 0)
    c = ConcurrentCalls.call(scheduler, add, 0)
    start = time_ns()
    for _ in 1:N
        a = ConcurrentCalls.call(scheduler, add, a)
        b = ConcurrentCalls.call(scheduler, add, b)
        c = ConcurrentCalls.call(scheduler, add, c)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(a) == fetch(b) == fetch(c) == 0
    report("triparallel", ns, N * 3, scheduler.stats)

    # fan-in
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = Vector{RemoteCall}(N)
    start = time_ns()
    for i in 1:N
        a[i] = ConcurrentCalls.call(scheduler, add, 0)
    end
    b = ConcurrentCalls.call(scheduler, add, a...)
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert fetch(b) == 0
    report("fan-in", ns, N + 1, scheduler.stats)

    # fan-out
    scheduler = ConcurrentCalls.Scheduler(workers)
    a = ConcurrentCalls.call(scheduler, add, 0)
    b = Vector{RemoteCall}(N)
    start = time_ns()
    for i in 1:N
        b[i] = ConcurrentCalls.call(scheduler, add, a)
    end
    ConcurrentCalls.teardown(scheduler)
    ns = time_ns() - start
    @assert all(fetch(b[i]) == 0 for i in 1:N)
    report("fan-out", ns, N, scheduler.stats)
end

println("## Version information\n")
println(indent(sprint(versioninfo)))

datetime_finish = now()
println("- started at $(datetime_start)")
println("- finished at $(datetime_finish)")
