module CLJReaderTest

using FactCheck
include("testutil.jl")
using .TestUtil.testdir

include("../src/transpiler.jl")
using .Transpiler

include("../src/util.jl")

macro symbol(s) symbol(s) end

function test(line)
  form, expr = split(line, " ||| ")
  # this might seem incongruent with the transpile function, which returns
  # an array of forms, but juila's parser auto-wraps everything into a block
  # when the parse function is called.
  e = parse(form)
  toplevel = isa(e, Expr) && (e.head == :(=) || e.head == :function)
  @fact(Util.oneline(Transpiler.detranspile(e, toplevel)) --> strip(expr),
        "expected $(Util.tosexp(parse(form))) -> $expr")
end

TestUtil.testdir(
  joinpath(dirname(@__FILE__), "jlfiles"),
  (x) -> true,
  test,
  '#')

end
