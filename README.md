# ConcurrentCalls.jl

[![TravisCI Status][travisci-img]][travisci-url]
[![codecov.io][codecov-img]][codecov-url]

## Usage

ConcurrentCalls.jl offers tools to call multiple tasks concurrently.
```julia
addprocs(2)
using ConcurrentCalls

function multitask()
    # Define some time-consuming (say >10ms) task(s).
    function sum(x, y)
        sleep(2)
        return x + y
    end
    function prod(x, y)
        sleep(1)
        return x * y
    end

    # Call functions concurrently using multiple processes.
    @cc begin
        x = sum(1, 2)       # =>  3
        y = sum(3, 4)       # =>  7
        prod(x, sum(y, 1))  # => 24
    end
end

multitask()
```

Code inside the `@cc` macro are executed in a different manner from usual code.
Functions are called concurrently without waiting previous function calls.  For
example, the second line may be executed before the first line if the second
does not depend on the first. If you start a Julia session with multiple
proceses (using `-p` option or with `addprocs` function), all function calls
will be delegated to worker processes and you may finish your job in smaller
elapsed time.

Since functions may be called in other processes, there is a significant
overhead compared to usual function calls. That means you need to be careful
about the granularity of each function call. If your function will finish within
a few microseconds, the overhead will be much higher than the cost of the
function call. The magnitude of the cost of remote function calls is, roughtly
speaking, 100-1000 microseconds. So, in order to enjoy performance benefits,
your tasks should take at least 1-10 milliseconds. Also, note that each `@cc`
block starts up a new task scheduler first and tears down it at the end, which
is a little bit costly work.

In the example above, we use [closures][closures] to define tasks. This is
because Julia's closures are serializable and can be passed to other processes.
Of course, you can use the `@everywhere` macro to define functions in a global
scope and share them among processes. Since these tasks may be run in other
processes, you cannot update neither global nor local variables in the
environment.

## Example: running external commands in parallel

Let's see a quick example to speed up your job. The following function
compresses files using the [xz](https://tukaani.org/xz/) command:
```julia
function xz_compress_concurrent(files)
    compress(input, output) = run(pipeline(input, `xz`, output))
    @cc for file in files
        compress(file, DevNull)
    end
end
```
[examples/xz.jl](/examples/xz.jl).

In a benchmark, it took 24.4 seconds to compress 3,000 files in serial
execution. But when we used four workers (`-p4`), it only took 5.7 seconds; the
speedup rate is >100%, this would be because workers compressed data using the
external command and tasks allocated to each worker were multiplexed.

## Example: counting words

In this example, we capture the results of tasks as an array:
```julia
function countwords_concurrent(files)
    function countwords(file)
        counts = Dict{String,Int}()
        for word in eachmatch(r"\w+", readstring(file))
            counts[word.match] = get!(counts, word.match, 0) + 1
        end
        return counts
    end
    return @cc [countwords(file) for file in files]
end
```
[examples/countwords.jl](/examples/countwords.jl).

In a benchmark, it took 7.0 seconds to process 3,000 files in serial.  The same
task took 2.7 seconds with four workers.

[closures]: https://docs.julialang.org/en/stable/devdocs/functions/#Closures-1
[travisci-img]: https://travis-ci.org/bicycle1885/ConcurrentCalls.jl.svg?branch=master
[travisci-url]: https://travis-ci.org/bicycle1885/ConcurrentCalls.jl
[codecov-img]: http://codecov.io/github/bicycle1885/ConcurrentCalls.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/bicycle1885/ConcurrentCalls.jl?branch=master
