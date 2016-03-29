module Transpiler

include("reader.jl")
import .Reader
include("parser.jl")
import .Parser
include("cljreader.jl")
import .CLJReader
include("util.jl")
import .Util

export transpile, lisp_str

transpile(str::AbstractString) =
  Util.delevel(map(x -> Reader.read(x...), zip(Parser.parsesexp(str)...)))

detranspile(ex, toplevel=false) =
  CLJReader.read(Util.tosexp(Util.stripmeta(ex)), toplevel)

"""
This is NOT efficient - it basically does the entire pipeline in reverse
because read requires line numbers. Of course, the line numbers returned by this
are entirely wrong!
It's not clear how to solve this efficiently, since read really does need
line numbers, and we'd like them to come from the macro itself.
It might be necessary to write out meta information to the macro so that when
something is returned we get something we can rehydrate easily.
That's probably the best solution.

For interpolated values, we can give -1 or something as a line number right now.
Macros are really complicated!
"""
rehydrate(ex) = Transpiler.transpile(Util.oneline(CLJReader.readquoted(ex)))

macro clj_str(str::AbstractString)
  transpile(str)
end

macro jl(ex::Expr)
  detranspile(ex)
end

end
