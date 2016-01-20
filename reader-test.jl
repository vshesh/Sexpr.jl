module ReaderTest

using FactCheck
include("parser.jl")
using .Parser
include("reader.jl")
using .Reader

"""
Used to remove LineNumberNodes (which are just metadata)
from expressions that are created in julia. When manually making the same
expression, the LineNumberNodes don't show up.

"""
function stripmeta(expr)
  if isa(expr, Expr)
    return Expr(expr.head, stripmeta(expr.args)...)
  elseif isa(expr, Array)
    return map(stripmeta, filter(x -> !isa(x, LineNumberNode), expr))
  else
    return expr
  end
end


function test(line)
  form, sexp, expr = split(line, " ||| ")
  @fact(Parser.parsesexp(form, false)[1] --> eval(parse(sexp)),
        "expected $form -> $sexp")
  @fact(Reader.read(map(x->x[1], Parser.parsesexp(form))...) -->
        stripmeta(eval(parse(expr))),
        "expected $form -> $expr")
end


DIRECTORY = "testfiles"

for filename in readdir(DIRECTORY)
  open(string(DIRECTORY, "/", filename)) do f
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
