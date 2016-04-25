module FormatterTest

using FactCheck
include("../src/formatter.jl")
using .Formatter: tostring

facts("Inline form tests") do
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
    # this test is dicey, since dict returns things in no particular order.
    @fact tostring(Dict(:x=>:y)) --> "Dict(\n  :x=>:y)"
  end
  
end

end
