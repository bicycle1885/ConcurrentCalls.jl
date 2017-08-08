# Chunking Generator
# ==================

struct ChunkingGenerator{I,F}
    scheduler::Scheduler

    iter::I

    func::F

    # maximum chunk size
    maxchunksize::Int

    # number of chunks in a chunking buffer
    nchunks::Int
end

function ChunkingGenerator(scheduler, iter, func)
    return ChunkingGenerator(
        scheduler, iter, func,
        scheduler.config.chunksize, 8)
end

function Base.iteratorsize(::Type{ChunkingGenerator{I,F}}) where {I,F}
    return Base.iteratorsize(I)
end

function Base.iteratoreltype(::Type{ChunkingGenerator{I,F}}) where {I,F}
    return Base.EltypeUnknown()
end

function Base.size(gen::ChunkingGenerator)
    return size(gen.iter)
end

mutable struct ChunkingGeneratorState{S}
    state::S
    done::Bool
    chunk::Vector
    remotecalls::Vector{RemoteCall}
end

function Base.start(gen::ChunkingGenerator)
    return ChunkingGeneratorState(start(gen.iter), false, [], RemoteCall[])
end

function Base.done(gen::ChunkingGenerator, state)
    while !state.done && length(state.remotecalls) < gen.nchunks
        chunk = eltype(gen.iter)[]
        while length(chunk) < gen.maxchunksize && !done(gen.iter, state.state)
            item, state.state = next(gen.iter, state.state)
            push!(chunk, item)
        end
        if isempty(chunk)
            state.done = true
        else
            # Assign `gen.func` to a variable so as not to serialize `gen`.
            f = gen.func
            rc = call(gen.scheduler, c -> map(f, c), chunk)
            push!(state.remotecalls, rc)
        end
    end
    return isempty(state.chunk) && isempty(state.remotecalls)
end

function Base.next(gen::ChunkingGenerator, state)
    if isempty(state.chunk)
        state.chunk = fetch(shift!(state.remotecalls))
    end
    item = shift!(state.chunk)
    return item, state
end
