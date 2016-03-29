module CLJReaderTest

using FactCheck
include("testutil.jl")
using .TestUtil.testdir

include("../src/transpiler.jl")
using .Transpiler

function test(line)
  form, expr = split(line, " ||| ")
  # this might seem incongruent with the transpile function, which returns
  # an array of forms, but juila's parser auto-wraps everything into a block
  # when the parse function is called.
  @fact(Transpiler.detranspile(parse(form), false) --> eval(parse(expr)),
        "expected $form -> $expr")
end

TestUtil.testdir(
  joinpath(dirname(@__FILE__), "jlfiles"),
  (x) -> true,
  test,
  '#')

end
