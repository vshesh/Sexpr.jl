module Transpiler

include("reader.jl")
import .Reader
include("parser.jl")
import .Parser

export transpile

transpile(str) = map(x -> Reader.read(x...), zip(Parser.parsesexp(str)...))

function stripmeta(expr)
  if isa(expr, Expr)
    return Expr(expr.head, stripmeta(expr.args)...)
  elseif isa(expr, Array)
    return map(stripmeta, filter(x -> !isa(x, LineNumberNode), expr))
  else
    return expr
  end
end

function showexpr(e::Expr)
  if e.head == :macro
    e.head = :function
    string("macro", @sprintf("%s", stripmeta(e))[9:end])
  else
    @sprintf("%s", stripmeta(e))
  end
end

end

if length(ARGS) > 0 && ARGS[1] in ("--run", "-r")
  eval(:(importall Transpiler))
  for form in Transpiler.transpile(readall(STDIN))
    println(form)
    println("\n")
  end
end





