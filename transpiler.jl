module Util

export stripmeta, tosexp, VECID, DICTID

VECID = :vect
DICTID = :dict

stripmeta(expr::Expr) = Expr(expr.head, stripmeta(expr.args)...)
stripmeta(expr::Array) = map(stripmeta, filter(x -> !isa(x, LineNumberNode), expr))
stripmeta(expr) = return expr

"""
tosexp takes a julia expression and outputs it as a tuple s-expression form.
this makes it much easier to write a reader for.
"""
tosexp(ex::Expr) = Any[ex.head, map(tosexp, ex.args)...]
tosexp(ex::QuoteNode) = tosexp(ex.value)
tosexp(ex) = ex


end


module Transpiler

include("reader.jl")
import .Reader
include("parser.jl")
import .Parser

export transpile, lisp_str

transpile(str::AbstractString) =
  map(x -> Reader.read(x...), zip(Parser.parsesexp(str)...))

macro lisp_str(str::AbstractString)
  transpile(str)
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





