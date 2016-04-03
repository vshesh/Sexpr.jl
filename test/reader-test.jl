module ReaderTest

using FactCheck

include("testutil.jl")

include("../src/parser.jl")
include("../src/reader.jl")
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


TestUtil.testdir(
  joinpath(dirname(@__FILE__), "cljfiles"),
  (x) -> true,
  test)


# Error testing
facts("Incorrect Number/Structure of Forms Test") do
  @fact_throws Reader.Errors.InvalidFormCountError Reader.read(Any["`", "x", "y"], Any[(1,1),(1,1),(1,1)])
  @fact_throws Reader.Errors.InvalidFormCountError Reader.read(Any["def"], Any[(1,1)])
  @fact_throws Reader.Errors.InvalidFormCountError Reader.read(Any["if", "test"], Any[(1,1), (1,1)])
  @fact_throws Reader.Errors.InvalidFormCountError Reader.read(Any["let"], Any[(1,1), (1,1)])
  @fact_throws Reader.Errors.InvalidFormCountError Reader.read(Any[:dict, "1"], Any[(1,1), (1,1)])
  @fact_throws Reader.Errors.InvalidFormStructureError Reader.read(Any["curly", Any["let"]], Any[(1,1), Any[(1,1)]])

  @fact_throws Reader.Errors.InvalidFormCountError Reader.readquoted(Any[:dict, "1"], Any[(1,1), (1,1)])

  @fact_throws Reader.Errors.InvalidTokenError Reader.readatom(":x.y", (1,1))
  
  @fact_throws Reader.Errors.InvalidFormStructureError Reader.read(Any["fn", "name", "doc", "oops"], Any[(1,1), Any[(1,1)]])
  
  # TODO this shouldn't be true, env vars in clojure look like *out* and things.
  @fact_throws Reader.Errors.InvalidTokenError Reader.readsym("+x*", (1,1))
  
  
end

end
