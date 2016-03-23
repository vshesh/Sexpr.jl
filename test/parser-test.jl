"""
So far this module contains only the most basic of tests for the reader.

Testing atoms (symbols, numbers, keywords, etc) is pretty thorough, as
is singleton list/vector/map reading.
There is some testing of comment fields and paren mismatches (the tests
are quite random though, aside from the trivial cases, I mostly button
mashed.)

It doesn't do any kind of pathological program checks; there's only one semi
program looking thing inside the comment checking section, and even that
example doesn't test maps.

Lots of TODOs here...
"""
module ParserTest

using FactCheck
include("../src/parser.jl")
using .Parser
using .Parser.Errors

# Special 1->many atom split cases
@fact parsesexp("\\c\\d", false) --> Any["\\c","\\d"]
@fact parsesexp("\"x\"\"y\"", false) --> Any["\"x\"", "\"y\""]

facts("Comments should be ignored") do
  # every ascii character
  @fact parsesexp("; `1234567809-=~!@#\$%^*(&)_+;:qwertweurpiouy[]{}\\|asdfghjkl'\\\"zxcvbn,m./<>?", false) --> Any[]
  @fact parsesexp("(defn identity ;[x] \n [x] x)", false) -->
    Any[Any["defn", "identity", Any[VECID, "x"],"x"]]
  realprogram = """
  ; mithril-js html macro
  (defn test
  ; now you can write (html (:div {:attr 1} (:div#id {:class "class"}))) etc
    ([x] x)
  ; intead of having to put 'm' in front of everything. it will ignore non
    ([x & body] [x body]))
  ; keyword entities.
  """
  @fact parsesexp(realprogram, false) -->
    Any[Any["defn", "test",
      Any[Any[VECID, "x"], "x"],
      Any[Any[VECID, "x", "&", "body"], Any[VECID, "x", "body"]]]]
end

# situations in which the parser should give "unclosed string error"
stringerrors = [
  # opening quote only
  "\"", "\"asjdfbasljwelfjkabwawbfakjwefawkjfb",
  # opening quote across newlines
  "\"asdjfaf\naslfkjasfs\n",
  # open quote in the "middle" of a symbol
  "askfasdfhak\"askjfhasdjf",
  # crazier symbol
  "::f!?:++o*o-b231212214_\"a.23412/c_r!+.*?",
  # some code
  "(defn f [x] \"oops i forgot to close this string )"
]

# missing parens of some kind in these forms.
notenoughparens = [
  "(", "[", "{", "(()", "(()()(())", "(((((((", "[[[[[[]]]]] [[]] [[]] ",
  "{{{{ }} {{}}", "{{}} {{"
  ]
toomanyparens = [
  ")", "]", "}", "((()))}", "(([[[[]]]])))", ")))(((())))"
  ]
mismatchedparens = [
  "(]", "[}", "{)", "{{{)))", "[[[]])]", "{{{}}]))))",
  "(((()))) (()) (() [[}])"
  ]

facts("Basic reader error checking") do
  for s in notenoughparens
    @fact_throws UnclosedError parsesexp(s, false) "$s"
  end

  for s in toomanyparens
    @fact_throws ExtraError parsesexp(s, false) "$s"
  end

  for s in mismatchedparens
    @fact_throws MismatchedError parsesexp(s, false) "$s"
  end
end

end
























