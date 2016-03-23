module ReaderTest

using FactCheck

include("../src/parser.jl")

include("../src/transpiler.jl")

include("../src/util.jl")
using .Util.tosexp

"""
There are some things I don't care about in the equality comparison.

* LineNumberNodes (which are just metadata) When manually making the same
  expression, the LineNumberNodes don't show up.
"""
function cleanex(ex::Expr, toplevel=true)
  if !toplevel && ex.head == :block
    children = cleanex(ex.args, false)
    if length(children) == 1
      children[1]
    else
      Expr(ex.head, children...)
    end
  else
    Expr(ex.head, cleanex(ex.args, false)...)
  end
end

cleanex(expr::Array, toplevel=true) = map(x->cleanex(x,false),
  filter(x -> !isa(x, LineNumberNode), expr))
cleanex(expr, toplevel=true) = expr


function test(line)
  form, sexp, expr = split(line, " ||| ")
  @fact(Parser.parsesexp(form, false)[1] --> eval(parse(sexp)),
        "expected $form -> $sexp")
  
  expected = cleanex(eval(parse(expr)))
  actual = cleanex(Transpiler.transpile(form)[1])
  @fact(actual --> expected,
        "expected $(tosexp(actual)) === $(tosexp(expected))")
end


DIRECTORY = joinpath(dirname(@__FILE__), "testfiles")

for filename in readdir(DIRECTORY)
  open(joinpath(DIRECTORY, filename)) do f
    facts(readline(f)) do
      line = nothing
      while !eof(f)
        line = readline(f)
        if match(r"^\s*$", line) == nothing && match(r"^\s*;", line) == nothing
          break
        end
      end
      while !eof(f)
        context(line) do
          while !eof(f)
            line = readline(f)
            if match(r"^\s*$", line) != nothing || match(r"^\s*;", line) != nothing
              continue
            end
            # break if we're on a context line
            if !contains(line, "|||") break end
            test(line)
          end
        end
      end
    end
  end
end

end
