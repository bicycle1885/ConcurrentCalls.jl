# RemoteCall
# ==========

struct RemoteCall
    # The task must return a future as the result value.
    call::Task
end

function Base.wait(rc::RemoteCall)
    return wait(rc.call)::Future
end

function Base.fetch(rc::RemoteCall)
    return fetch(wait(rc))
end

function Base.map(f, rc::RemoteCall)
    return f(rc)
end

function Base.serialize(::AbstractSerializer, rc::RemoteCall)
    throw(ArgumentError("cannot serialize a RemoteCall object"))
end
