# File: roundtriptests.jl
# Author: Vishesh Gupta
# Created: 3 April 2016

# The purpose of this file is to contain tests that ensure that roundtrip
# transpilation works as expected. In other words
# detranspile(transpile("; clj form goes here ")) --> clj form
# transpile(detranspile(:(julia form ))) --> equivalent julia form .

# also testing other parts of Sexpr.jl like rehydrate.


module RoundtripTests

using FactCheck
include("../src/Sexpr.jl")

facts("Sexpr.rehydrate tests") do
  # rehydrating atoms
  @fact Sexpr.rehydrate(1) --> 1
  @fact Sexpr.rehydrate(:x) --> :x
  # rehydrating forms
  @fact Sexpr.rehydrate((:symbol, "a", 1)) --> :(symbol("a", 1))
  @fact Sexpr.rehydrate((:if, true, 1, 0)) --> :(true ? 1 : 0)
end

end
