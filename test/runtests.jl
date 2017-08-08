using ConcurrentCalls
using Base.Test

@testset "RemoteCall" begin
    @test_throws ArgumentError serialize(IOBuffer(), ConcurrentCalls.RemoteCall(@task 1))
end

@testset begin
    scheduler = ConcurrentCalls.Scheduler()
    a = ConcurrentCalls.call(scheduler, +, 1, 1)
    ConcurrentCalls.teardown(scheduler)
    @test fetch(a) == 2
    @test sprint(show, scheduler.stats) isa String
end

@testset begin
    scheduler = ConcurrentCalls.Scheduler()
    a = ConcurrentCalls.call(scheduler, +, 1, 1)
    b = ConcurrentCalls.call(scheduler, +, 1, 2)
    c = ConcurrentCalls.call(scheduler, +, a, b)
    ConcurrentCalls.teardown(scheduler)
    @test fetch(c) == 5
    @test sprint(show, scheduler.stats) isa String
end

@testset begin
    scheduler = ConcurrentCalls.Scheduler()
    a = ConcurrentCalls.call(scheduler, +, 0, 0)
    for _ in 1:5
        a = ConcurrentCalls.call(scheduler, +, a, 1)
    end
    ConcurrentCalls.teardown(scheduler)
    @test fetch(a) == 5
    @test sprint(show, scheduler.stats) isa String
end

@testset "pmap" begin
    scheduler = ConcurrentCalls.Scheduler()
    a = ConcurrentCalls.pmap(scheduler, x->2x, collect(1:100))
    ConcurrentCalls.teardown(scheduler)
    @test fetch.(a) == map(x->2x, collect(1:100))

    scheduler = ConcurrentCalls.Scheduler()
    a = ConcurrentCalls.pmap(scheduler, x->2x, collect(1:100))
    ConcurrentCalls.teardown(scheduler)
    @test fetch.(a) == map(x->2x, collect(1:100))

    scheduler = ConcurrentCalls.Scheduler()
    a = ConcurrentCalls.pmap(scheduler, x->2x, (i for i in 1:100 if rand() ≥ 0))
    ConcurrentCalls.teardown(scheduler)
    @test fetch.(a) == map(x->2x, collect(1:100))
end

@testset "ChunkingGenerator" begin
    scheduler = ConcurrentCalls.Scheduler()
    gen = ConcurrentCalls.ChunkingGenerator(scheduler, 1:100, x->x/2)
    @test collect(gen) == map(x->x/2, 1:100)
    ConcurrentCalls.teardown(scheduler)

    scheduler = ConcurrentCalls.Scheduler()
    gen = ConcurrentCalls.ChunkingGenerator(scheduler, 1:100, identity)
    result = mapreduce(x->2x, +, gen)
    ConcurrentCalls.teardown(scheduler)
    @test result === mapreduce(x->2x, +, 1:100)
end

@testset begin
    # fetch before teardown
    scheduler = ConcurrentCalls.Scheduler()
    ret = ConcurrentCalls.call(scheduler, +, 1, 1)
    val = fetch(ret)
    ConcurrentCalls.teardown(scheduler)
    @test val == 2
end

@testset "@cc" begin
    val = @cc 1
    @test val == 1

    val = @cc 1 + 1
    @test val == 2

    val = @cc begin
        1 + 2
    end
    @test val == 3

    val = @cc begin
        a = 1 + 1
        a * 2
    end
    @test val == 4

    x = 4
    val = @cc begin
        x + 1
    end
    @test val == 5

    x = 2
    val = @cc begin
        (y -> x + y)(4)
    end
    @test val == 6

    val = @cc begin
        a = pmap(1:3) do x
            x
        end
        a[1] + a[2] + a[3] + 1
    end
    @test val == 7

    val = @cc pmap(x->2x, 1:3)
    @test val == [2,4,6]

    #=
    val = @cc begin
        a = [i * 2 for i in 1:10]
        sum(a)
    end
    @test val == 110
    =#

    val = @cc (x + 1 for x in 1:3)
    @test val == [2,3,4]

    val = @cc [x + 1 for x in 1:3]
    @test val == [2,3,4]
end

#=
@testset begin
    foo(x) = x + 1
    bar(x) = 2x
    baz(x) = 3x
    xs = [1,2,3,4]
    val = @cc begin
        xs = [foo(x) for x in xs]
        xs = [bar(x) for x in xs]
        xs = [baz(x) for x in xs]
        sum(xs)
    end
    @test val == 84
end
=#
