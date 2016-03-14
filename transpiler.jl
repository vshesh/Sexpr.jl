module Transpiler

include("reader.jl")
import .Reader
include("parser.jl")
import .Parser
include("cljreader.jl")
import .CLJReader
import ..Util

export transpile, lisp_str

transpile(str::AbstractString) =
  map(x -> Reader.read(x...), zip(Parser.parsesexp(str)...))

detranspile(ex::Expr) =
  CLJReader.read(Util.stripmeta(Util.tosexp(ex)))

macro clj_str(str::AbstractString)
  transpile(str)
end

macro jl(ex::Expr)
  detranspile(ex)
end

end


# parse only
# transpile from clj -> lisp (done)
# lisp str macro (done)

if length(ARGS) > 0 && ARGS[1] in ("--run", "-r")
  eval(:(importall Transpiler))
  for form in Transpiler.transpile(readall(STDIN))
    println(form)
    println("\n")
  end
end





