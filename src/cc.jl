# Concurrent Call Macro
# =====================

"""
    @cc expr

Take an expression `expr` and override function calls in the concurrent style.
"""
macro cc(ex)
    if ex isa Expr
        return cc_transform(ex)
    else
        return ex
    end
end

function cc_transform(ex::Expr)
    scheduler = gensym(:scheduler)
    quote
        $(scheduler) = $(Scheduler)()
        try
            $(Base.map)($(Base.fetch), $(rewrite_funccalls(ex, scheduler)))
        catch
            $(Base.rethrow)()
        finally
            $(teardown)($(scheduler))
            # println(sprint(show, $(scheduler).stats))
            # println(STDOUT, $(scheduler).trace)
        end
    end
end

function rewrite_funccalls(ex::ANY, scheduler::Symbol)
    if !(ex isa Expr)
        return ex isa Symbol ? esc(ex) : ex
    end
    rewrite(ex) = rewrite_funccalls(ex, scheduler)
    head = ex.head
    args = ex.args
    if head == :call  # function call
        if length(args) > 0 && args[1] == :pmap
            return Expr(:call, ConcurrentCalls.pmap, scheduler, map(rewrite, args[2:end])...)
        else
            return Expr(:call, ConcurrentCalls.call, scheduler, map(rewrite, args)...)
        end
    elseif head == :generator
        @assert length(args) == 2
        @assert args[2].head == :(=)
        iter = args[2].args[2]
        closure = Expr(:->, esc(args[2].args[1]), esc(args[1]))
        return Expr(:call, ConcurrentCalls.ChunkingGenerator, scheduler, rewrite(iter), closure)
    elseif head == :comprehension
        @assert length(args) == 1
        return Expr(:call, collect, rewrite(args[1]))
    elseif head == :->  # closure
        return esc(ex)
    else
        return Expr(head, map(rewrite, args)...)
    end
end
