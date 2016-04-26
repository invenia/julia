# This file is a part of Julia. License is MIT: http://julialang.org/license

# Date/DateTime Ranges

# Override default step; otherwise it would be Millisecond(1)
Base.colon{T<:DateTime}(start::T, stop::T) = StepRange(start, Day(1), stop)
Base.colon(start::GeneralPeriod, stop::GeneralPeriod) = colon(start, Day(1), stop)

# function Base.colon(x::Period, y::Period)
#     z = typeof(x)<typeof(y)? one(x):one(y)
#      colon(x, z, y)
#  end

function Base.colon(x::GeneralPeriod, y::GeneralPeriod, z::GeneralPeriod)
    if typeof(x) != typeof(z)
        if typeof(x)<:Period
            x=CompoundPeriod(x)
        end
        if typeof(z)<:Period
            z=CompoundPeriod(z)
        end
    end
    if typeof(y) == CompoundPeriod
        y = Millisecond(toms(y))
    end
    StepRange(x,y,z)
end

function Base.show(io::IO, r::StepRange{CompoundPeriod, Millisecond})
    step = CompoundPeriod(r.step)
    print(io, repr(first(r)), ':', repr(step), ':', repr(last(r)))
end

# Given a start and end date, how many steps/periods are in between
guess(a::DateTime,b::DateTime,c) = floor(Int64,(Int128(b) - Int128(a))/toms(c))
guess(a::Date,b::Date,c) = Int64(div(Int64(b - a),days(c)))
function len(a,b,c)
    lo, hi, st = min(a,b), max(a,b), abs(c)
    i = guess(a,b,c)-1
    while lo+st*i <= hi
        i += 1
    end
    return i-1
end
Base.length{T<:TimeType}(r::StepRange{T}) = isempty(r) ? 0 : len(r.start,r.stop,r.step) + 1
# Period ranges hook into Int64 overflow detection
Base.length{P<:Period}(r::StepRange{P}) = length(StepRange(value(r.start),value(r.step),value(r.stop)))

# Used to calculate the last valid date in the range given the start, stop, and step
# last = stop - steprem(start,stop,step)
Base.steprem{T<:TimeType}(a::T,b::T,c) = b - (a + c*len(a,b,c))

import Base.in
function in{T<:TimeType}(x::T, r::StepRange{T})
    n = len(first(r),x,step(r)) + 1
    n >= 1 && n <= length(r) && r[n] == x
end

Base.start{T<:TimeType}(r::StepRange{T}) = 0
Base.next{T<:TimeType}(r::StepRange{T}, i::Int) = (r.start+r.step*i,i+1)
Base.done{T<:TimeType,S<:Period}(r::StepRange{T,S}, i::Integer) = length(r) <= i

.+{T<:TimeType}(x::Period, r::Range{T}) = (x+first(r)):step(r):(x+last(r))
.+{T<:TimeType}(r::Range{T},x::Period) = x .+ r
+{T<:TimeType}(r::Range{T},x::Period) = x .+ r
+{T<:TimeType}(x::Period,r::Range{T}) = x .+ r
.-{T<:TimeType}(r::Range{T},x::Period) = (first(r)-x):step(r):(last(r)-x)
-{T<:TimeType}(r::Range{T},x::Period) = r .- x
