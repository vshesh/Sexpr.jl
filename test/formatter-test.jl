module FormatterTest

using FactCheck
include("../src/util.jl")
using .Util: stripmeta
include("../src/formatter.jl")
using .Formatter: tostring

facts("Atoms Formatting Tests") do
  context("nil/booleans") do
    @fact tostring(nothing) --> "nil"
    @fact tostring(true) --> "true"
    @fact tostring(false) --> "false"
  end
  
  context("numbers") do
    @fact tostring(14812983712937129873123) --> "14812983712937129873123"
    @fact tostring(UInt8(123)) --> "0x7b"
    @fact tostring(3//5) --> "3//5"
  end
  
  context("characters") do
    @fact tostring('c') --> "'c'"
  end
  
  context("strings") do
    @fact tostring("123498712394ksjhanvas;lkva'kaskv(*&^*)&[]]]]]]]}") -->
      "\"123498712394ksjhanvas;lkva'kaskv(*&^*)&[]]]]]]]}\""
  end
  
  context("quotenodes/symbols") do
    @fact tostring(QuoteNode(:x)) --> ":x"
    @fact tostring(:x) --> "x"
    @fact tostring(:ausdf983012039) --> "ausdf983012039"
  end
  
  context("collections") do
    @fact tostring((:x,:y,:z)) --> "(x,y,z)"
    @fact tostring([:x,:y,:z]) --> "[x,y,z]"
    # this looks weird, but matches the other collections.
    # ultimately, tostring should really be operating on expression
    # objects, so tostring for a dictionary with keyword components will
    # come out like this.
    @fact tostring(Dict(:x=>:y)) --> "Dict(\n  x => y)"
  end
end

facts("Expression Formatting Tests") do
  # in order of appearance in formatter.jl
  @fact tostring(Expr(://, 3, 5)) --> "3//5"
  
  @fact tostring(:((x,y,z))) --> "(x,y,z)"
  @fact tostring(:([x,y,z])) --> "[x,y,z]"
  @fact tostring(:(Dict(:x=>:y))) --> "Dict(\n  :x => :y)"
  
  @fact tostring(Expr(:quote, :x)) --> ":x"
  @fact tostring(Expr(:quote, :(1 + 1))) --> ":(+(1, 1))"
  
  @fact tostring(Expr(:$, :x)) --> "\$x"
  @fact tostring(Expr(:$, :(1 + 1))) --> "\$(+(1, 1))"
  
  @fact tostring(Expr(:...,:x)) --> "x..."
  
  @fact tostring(stripmeta(:(begin x end))) --> "x"
  @fact tostring(stripmeta(:(begin x; y end))) --> "begin\n  x\n  y\nend"
  
  @fact tostring(stripmeta(:(if true 1 else 0 end))) --> "if true\n  1\nelse\n  0\nend"
  @fact tostring(stripmeta(:(if true 1 end))) --> "if true\n  1\nend"

  @fact tostring(stripmeta(Expr(:comparison, 1, :>, 2))) --> "(1 > 2)"
  
  @fact tostring(stripmeta(:(let x=1; x end))) --> "let x = 1\n  x\nend"
  
  @fact tostring(stripmeta(:(function f(x) x end))) --> "function f(x)\n  x\nend"
  @fact tostring(stripmeta(:(function f(x) x; x+1 end))) --> "function f(x)\n  x\n  +(x, 1)\nend"
  
  @fact tostring(stripmeta(:(x->x))) --> "x -> x"
  @fact tostring(stripmeta(:((x,y)->x+y))) --> "(x,y) -> +(x, y)"
  
  @fact tostring(:(x = 1)) --> "x = 1"
  
  @fact tostring(:(x[1:2])) --> "x[1:2]"
  
  @fact tostring(stripmeta(:(module M end))) --> "module M\n\nend"
  @fact tostring(stripmeta(:(module M; function f(x) x end end))) --> "module M\n  function f(x)\n    x\n  end\nend"
  
  @fact tostring(stripmeta(:(using X.y))) --> "using X.y"
  @fact tostring(stripmeta(:(export x,y,z))) --> "export x,y,z"
  
  @fact tostring(:(x.y.z.a.b)) --> "x.y.z.a.b"
  @fact tostring(:(x::Int)) --> "x::Int"
  
  @fact tostring(:(@f(x,y))) --> "@f(x, y)"
  @fact tostring(:(f(x,y))) --> "f(x, y)"
  
  @fact tostring(:(import x, y)) --> "import x\nimport y"
  
  @fact tostring(Expr(:random)) --> "ERROR: could not print $(Expr(:random)) :ERROR"
end

end
