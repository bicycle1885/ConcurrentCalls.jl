#!/usr/bin/env julia

using ConcurrentCalls

function xz_compress_serial(files)
    compress(input, output) = run(pipeline(input, `xz`, output))
    for file in files
        compress(file, DevNull)
    end
end

function xz_compress_concurrent(files)
    compress(input, output) = run(pipeline(input, `xz`, output))
    @cc for file in files
        compress(file, DevNull)
    end
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

println("--- xz_compress_serial ---")
xz_compress_serial(files[1:1])
for _ in 1:3
    @time xz_compress_serial(files)
end
println()

println("--- xz_compress_concurrent ---")
xz_compress_concurrent(files[1:1])
for _ in 1:3
    @time xz_compress_concurrent(files)
end

#= 2017/08/29 on tostoint01
-bash-4.1$ find ~/anaconda3/ -type f -name "*.py" | head -3000 | julia -p4 examples/xz.jl
--- statistics ---
number of files:     3000
mean of filesizes:   10472.5
median of filesizes: 3743.5
std. of filesizes:   28214.8

--- xz_compress_serial ---
 25.834263 seconds (141.13 k allocations: 6.016 MiB)
 24.428520 seconds (141.13 k allocations: 6.016 MiB)
 24.663476 seconds (141.13 k allocations: 6.016 MiB)

--- xz_compress_concurrent ---
  6.535346 seconds (13.50 M allocations: 230.372 MiB, 1.61% gc time)
  5.665914 seconds (12.15 M allocations: 206.275 MiB, 1.12% gc time)
  5.747123 seconds (12.41 M allocations: 210.338 MiB, 1.28% gc time)
=#
