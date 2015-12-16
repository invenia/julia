# This file is a part of Julia. License is MIT: http://julialang.org/license

"Simple stack traces that are both human readable and easy to use programmatically."
module StackTraces


import Base: hash, ==

export stacktrace, catch_stacktrace, format_stacktrace, format_stackframe, show_stacktrace

"Stack information representing execution context."
immutable StackFrame
    "the name of the function containing the execution context"
    func::Symbol
    "the name of the file containing the execution context"
    file::Symbol
    "the line number in the file containing the execution context"
    line::Int
    "the name of the file containing the execution context for inlined code"
    inlined_file::Symbol
    "the line number in the file containing the execution context for inlined code"
    inlined_line::Int
    "true if the code is from C"
    from_c::Bool
    "representation of the pointer to the execution context as returned by `Base.backtrace`"
    pointer::Int64  # Large enough to be read losslessly on 32- and 64-bit machines.
end

"""
An alias for `Vector{StackFrame}` provided for convenience; returned by calls to
`stacktrace`.
"""
typealias StackTrace Vector{StackFrame}


"A placeholder for unknown execution context."
const UNKNOWN = StackFrame(:?, :?, -1, :?, -1, true, 0)

#=
If the StackFrame has function and line information, we consider two of them the same if
they share the same function/line information. For unknown functions, line == pointer, so we
never actually need to consider the pointer field.
=#
function ==(a::StackFrame, b::StackFrame)
    a.line == b.line && a.from_c == b.from_c && a.func == b.func && a.file == b.file
end

function hash(frame::StackFrame, h::UInt)
    h += 0xf4fbda67fe20ce88 % UInt
    h = hash(frame.line, h)
    h = hash(frame.file, h)
    h = hash(frame.func, h)
end


"Given a pointer, looks up stack frame context information."
function lookup(pointer::Ptr{Void})
    frame_info = ccall(:jl_lookup_code_address, Any, (Ptr{Void}, Cint), pointer, 0)
    return (length(frame_info) == 7) ? StackFrame(frame_info...) : UNKNOWN
end

lookup(pointer::UInt) = lookup(convert(Ptr{Void}, pointer))

"""
Returns a stack trace in the form of a vector of `StackFrame`s. (By default stacktrace
doesn't return C functions, but this can be enabled.)
"""
function stacktrace(trace::Vector{Ptr{Void}}, c_funcs::Bool=false)
    stack = map(lookup, trace)

    # Remove frames that come from C calls.
    if !c_funcs
        filter!(frame -> !frame.from_c, stack)
    end

    # Remove frame for this function (and any functions called by this function).
    remove_frames!(stack, :stacktrace)
end

"When called without specifying a trace, `stacktrace` uses `Base.backtrace`."
stacktrace(c_funcs::Bool=false) = stacktrace(backtrace(), c_funcs)

"Returns the stack trace for the most recent error thrown, rather than the current context."
catch_stacktrace(c_funcs::Bool=false) = stacktrace(catch_backtrace(), c_funcs)

"""
Takes a `StackTrace` (a vector of `StackFrames`) and a function name (a `Symbol`) and
removes the `StackFrame` specified by the function name from the `StackTrace` (also removing
all frames above the specified function). Primarily used to remove `StackTraces` functions
from the `StackTrace` prior to returning it.
"""
function remove_frames!(stack::StackTrace, name::Symbol)
    splice!(stack, 1:findlast(frame -> frame.func == name, stack))
    return stack
end

function remove_frames!(stack::StackTrace, names::Vector{Symbol})
    splice!(stack, 1:findlast(frame -> in(frame.func, names), stack))
    return stack
end

"Returns a string representation of a `StackFrame` for display purposes."
function format_stackframe(frame::StackFrame; full_path::Bool=false)
    file_info = "$(full_path ? frame.file : basename(string(frame.file))):$(frame.line)"

    if frame.inlined_file != Symbol("")
        inline_info = string("[inlined code from ", file_info, "] ")
        file_info = string(
            full_path ? frame.inlined_file : basename(string(frame.inlined_file)),
            ":", frame.inlined_line
        )
    else
        inline_info = ""
    end

    return string(inline_info, frame.func != "" ? frame.func : "?", " at ", file_info)
end

"Returns a string representation of a `StackTrace` for display purposes."
function format_stacktrace(
    stack::StackTrace, separator::AbstractString, start::AbstractString="",
    finish::AbstractString=""; full_path::Bool=false
)
    if isempty(stack)
        return ""
    end

    string(
        start,
        join(map(f -> format_stackframe(f, full_path=full_path), stack), separator),
        finish
    )
end

"An analogue of Base.show_backtrace that prints the stacktrace to the specified IO stream."
function show_stacktrace(io::IO, stack::StackTrace; full_path::Bool=false)
    println(
        io, "StackTrace with $(length(stack)) StackFrames$(isempty(stack) ? "" : ":")",
        format_stacktrace(stack, "\n  ", "\n  "; full_path=full_path)
    )
end

show_stacktrace(; full_path::Bool=false) = show_stacktrace(STDOUT; full_path=full_path)

function show_stacktrace(io::IO; full_path::Bool=false)
    show_stacktrace(io, remove_frames!(stacktrace(), :show_stacktrace); full_path=full_path)
end

function show_stacktrace(stack::StackTrace; full_path::Bool=false)
    show_stacktrace(STDOUT, stack; full_path=full_path)
end


end
