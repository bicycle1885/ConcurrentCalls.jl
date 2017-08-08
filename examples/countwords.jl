#!/usr/bin/env julia

using ConcurrentCalls

function countwords_serial(files)
    function countwords(file)
        counts = Dict{String,Int}()
        for word in eachmatch(r"\w+", readstring(file))
            counts[word.match] = get!(counts, word.match, 0) + 1
        end
        return counts
    end
    return [countwords(file) for file in files]
end

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

files = readlines(STDIN)
if isempty(files)
    error("no input files")
end

println("--- statistics ---")
filesizes = map(filesize, files)
println("number of files:     $(length(files))")
println("mean of filesizes:   $(@sprintf("%.1f", mean(filesizes)))")
println("median of filesizes: $(@sprintf("%.1f", median(filesizes)))")
println("std. of filesizes:   $(@sprintf("%.1f", std(filesizes)))")
println()

println("--- countwords_serial ---")
countwords_serial(files[1:1])
for _ in 1:3
    @time countwords_serial(files)
end
println()

println("--- countwords_concurrent ---")
countwords_concurrent(files[1:1])
for _ in 1:3
    @time countwords_concurrent(files)
end

#= 2017/08/29 tostoint01
-bash-4.1$ find ~/anaconda3/ -type f -name "*.py" | head -3000 | julia -p4 examples/countwords.jl
--- statistics ---
number of files:     3000
mean of filesizes:   10472.5
median of filesizes: 3743.5
std. of filesizes:   28214.8

--- countwords_serial ---
  7.094024 seconds (28.20 M allocations: 1.252 GiB, 11.39% gc time)
  7.005876 seconds (28.20 M allocations: 1.252 GiB, 10.69% gc time)
  7.027203 seconds (28.20 M allocations: 1.252 GiB, 10.74% gc time)

--- countwords_concurrent ---
  3.208697 seconds (915.67 k allocations: 90.871 MiB, 2.09% gc time)
  2.668285 seconds (900.71 k allocations: 89.754 MiB, 4.32% gc time)
  2.911208 seconds (900.89 k allocations: 89.006 MiB, 3.81% gc time)
=#
