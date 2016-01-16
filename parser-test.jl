module ParserTest

using FactCheck
include("parser.jl")
using .Parser
using .Parser.Errors
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


# Note that the reader can read/parse things that are not valid, it's the
# analyzer's job to figure out what is and isn't proper.
atoms = [
  # Symbols (variables in julia)
  "x", "X", "foobar", "foo-bar",
  "foo-bar?", "foo__bar?", ":foo-bar", ":FOOBAR_foobar_-foobaar1?",
  "FOOBAR!!!!!!!!", "fOo-bOr!!!!!!?12424+", "foo-b_a'_r:!+.*?",
  "@macro", "x@y",
    # random 15 char symbols
  "a5rNtvlIOveaQBQL", "aINNo0T2bmf7N8PE", "aZjT35MqHjNNcKYe",
  "a17wCv639cgcEjRV", "aHQmVVHhYaEuYrrL", "awGoUtSrYncOYjno",
  "ah1mrXbAJ1T1G9Hv", "aF3AExS1D7K3qTE3", "ajIDc27JWXGzie1U",
  # Keywords (symbols in julia)
  ":12", ":1238123", ":x", ":foobar", ":foo-bar", ":foo-bar!?",
  ":foo-b__ar!_.*?94810293123", "::f!?:++o*o-b_a.x/c_r!+.*?",
  # Numeric literals
  "1", "1.0", "2.0", "0.1238139", ".2293841",
  "10r16", "1871293812398130912301928312308r10",
  # Character literals
  "\\x", "\\newline", "\\formfeed", "\\backspace", "\\n", "\\v", "\\b", "\\return",
  "\\space", "\\return", "\\d",
  # Booleans and nil
  "nil", "true", "false",
  # Special macro characters ',`,~,~@,#,^,#_ TODO(vishesh)

  # String literals
  "\"\"", "\"a\"", "\"!@#\$%!%#!\"",
  # every ascii character
  "\"`1234567809-=~!@#\$%^*(&)_+qwerrtweurpiouy[]{}\\|asdfghjkl;:\\\"zxcvbn,m./<>?\"",
  # random ascii characters
  "\"F#p.PqG4hqY=+|n\"","\":FfJzo!.3c^.U+B\"","\"(xNQ@u&_Tuz^<>%\"",
  "\"EiEDwpo7L%G.vu8\"","\"Jc[Yu#=6M8\$7(3b\"","\"L1Sq<;;;/.>I+P!va?\"",
  "\"3X]8n]Gi*A@Pn:O\"","\"FG4=Dm78**0Be~0s!\\\"\"","\"vy;_ajA9!D{0uR//\"",
  ]

facts("Parser.parsesexp(atom) --> [atom]") do
  for a in atoms
    @fact parsesexp(a) --> Any[a]
  end

  # Special 1->many atom split cases
  @fact parsesexp("\\c\\d") --> Any["\\c","\\d"]
  @fact parsesexp("\"x\"\"y\"") --> Any["\"x\"", "\"y\""]
end

# Singleton List Literal
facts("Parser.parsesexp(\"(atom)\") --> [[atom]] ") do
  for a in atoms
    @fact parsesexp(string("(",a,")")) --> Any[Any[a]]
  end
end

# Singleton Vector Literal
facts("Parser.parsesexp(\"[atom]\") --> [[VECID, atom]] ") do
  for a in atoms
    @fact parsesexp(string("[",a,"]")) --> Any[Any[VECID, a]]
  end
end

# Singleton Map Literal (NOTE THIS IS NOT A LEGAL FORM,
#                        either you need `#` for a set, or a pair of forms)
facts("Parser.parsesexp(\"{atom}\") --> [[DICTID, atom]] ") do
  for a in atoms
    @fact parsesexp(string("{",a,"}")) --> Any[Any[DICTID, a]]
  end
end


facts("Comments should be ignored") do
  # every ascii character
  @fact parsesexp("; `1234567809-=~!@#\$%^*(&)_+;:qwertweurpiouy[]{}\\|asdfghjkl'\\\"zxcvbn,m./<>?") --> Any[]
  @fact parsesexp("(defn identity ;[x] \n [x] x)") -->
    {{"defn", "identity", {VECID, "x"},"x"}}
  realprogram = """
  ; mithril-js html macro
  (defn test
  ; now you can write (html (:div {:attr 1} (:div#id {:class "class"}))) etc
    ([x] x)
  ; intead of having to put 'm' in front of everything. it will ignore non
    ([x & body] [x body]))
  ; keyword entities.
  """
  @fact parsesexp(realprogram) -->
    {{"defn", "test",
      {{VECID, "x"}, "x"},
      {{VECID, "x", "&", "body"}, {VECID, "x", "body"}}}}
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
    @fact_throws UnclosedError parsesexp(s) "$s"
  end

  for s in toomanyparens
    @fact_throws ExtraError parsesexp(s) "$s"
  end

  for s in mismatchedparens
    @fact_throws MismatchedError parsesexp(s) "$s"
  end
end

end
























