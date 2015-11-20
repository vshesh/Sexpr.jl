# S-Julia - s-expression to julia convertor.

## Overview

Goal: Taking the syntax of clojure (or something close enough) and
translating it to a julia `Expr` object. This shouldn't be
hard to do since Julia has a nice syntax already set up for this purpose!

Then, look into doing julia -> clojure syntax. This may not be the cleanest,
since Julia's reader tends to aggressively wrap things in blocks (ie., `do`
from clojure), but it should still work.

Final goal - use this to do a `macroexpand` operation on the input clj syntax.
Basically, process all user-defined macros and output the resultant program,
but back to clojure syntax.
This would be useful for things like wispjs, where the translator can do
everything, but the macro system sucks.

Effectively, this is just the **reader** portion of implementing a lisp - I
take care of doing the rest of the code evaluation.

## Task List/Implementation Plan

### Reader
Takes in a file full of forms and returns an object (a list, probably) that
contains the tree structure of the form.

#### Read () enclosing operations (and strings) `done`

There is already this algorithm (written in python).

```python
#Sample Usage:
#>>> parse_sexp("(+ 5 (+ 3 5))")
#[['+', '5', ['+', '3', '5']]]
def parse_sexp(string):
  sexp = [[]]
  word = ''
  in_str = False
  for c in string:
    if c == '(' and not in_str:
      sexp.append([])
    elif c == ')' and not in_str:
      if(len(word) > 0):
        sexp[-1].append(word)
        word = ''
      temp = sexp.pop()
      sexp[-1].append(temp)
    elif c in (' ', '\n', '\t') and not in_str:
      if len(word) > 0:
        sexp[-1].append(word)
        word = ''
    elif c == '\"':
      in_str = not in_str
    else:
      word = word + c
  return sexp[0]
```

I've ported it to julia in reader.jl.
I can read basic s-expressions into Vectors (julia's version, at least),
including quoted environments with escaped quotes.

#### Read [...] forms and convert them to `(:__vect__ ...)` `done`
I need some intermediate vector form to convert the vector literals into.
This is because special forms often have bindings as a vector after their
name. For everything else, it's just a vector literal.

eg `(let [x 1 y 2 z 3] ...body)` isn't creating a vector literal, it's
a special form that has a binding site expressed as a vector.

#### Read {...} forms and convert them to `(:__dict__ ...)` `done`

Same deal, but this time with maps. Normally maps aren't going to be part of
anything other than just being a map, but destructuring is one example where
a map has special meaning. However, I still think that this should be an issue
for the analyzer to deal with rather than the reader.

#### Ignore comments `done`

remove all ranges that look like `; .... \n` from the input file.
It's possible to be fancier with this by generating a (comment "string")
form but then it would be necessary to somehow eval this into an actual
julia comment through it's s-expression syntax, which doesn't seem possible
as of now. Eg, `:(#1)` just confuses the reader (it thinks the paren never
closes).

#### Docstring mapping

There's a larger issue of mapping docstrings, which seems like it's not
going to be possible. Currently julia's s-expression system chokes on docstrings
followed by definitions (eg, functions).
The only possible workaround is dropping a docstring inside a function (this
is how clojure's syntax natively defines things anyway), except it ultimately
compiles down to a single quoted string, not a triple quoted string. Note that
this can't be worked around because there's no docstring function or any other
way to hint to julia that docstrings are separate from regular strings.

#### Treat `,` like whitespace `done`
Clojure syntax ignores all commas.

#### Reader macro special character combos (',`,~,~@,^,#)

~ and ~@ are their own tiny state machine, sigh. # is also it's own ball of
joy. The others can be just recognized on sight.
`'` and `#` are allowed to be part of a symbol too, so need to check
`length(word) == 0` when detecting those. `~,@,^,\`` aren't, so those can
just be recognized on sight.

#### Character Literals `done`

Need to read things like `\\c` as a character.
There's a few special ones too: `\\c, \\newline, \\space, \\tab, \\formfeed, \\backspace \\return` and unicode/octal situations too `\\uNNNN` or `\\oNNN`

Basically, `\\` boundary defines a new token, and it ends on the next token.

#### Line/col number `partially done`

(done) Maintain two state variables - 1 for lineno that increments on finding '\n' and another for colno that increments on anything else (and resets on '\n').

Also need a way to store this information for other parts of the translator,
and that is pending. As of now the errors aren't very helpful because they
don't say where they happened.
One cleanish idea is to store return a second tree with line/colnos for each
symbol. This isn't complete in that you still need line/colnos for all the
kinds of brackets, but it could be a good start.

I suppose the real solution is to wrap everything in a dictionary, but it just
looks messy:

```clojure
(println (str "h" "ello")) =>

{:line 1
 :col 1
 :sexp: [{:line 1 :col 2 :sexp "println"}
         {:line 1 :col 10 :sexp [{:line 0 :col 11 :sexp "str"}
                                 {:line 0 :col 15 :sexp "h"}
                                 {:line 0 :col 17 :sexp "ello"}]}]}
```

Actually, maybe not so messy. I suppose this is manageable.
It just makes detecting special forms a little more cumbersome, since you
have to do ["sexp"] each time on the children.
It also makes tests a little harder to write. I have to extract the
s-expression out of the dictionary.

#### Error Handling

The reader can't catch a lot of errors, but it should be able to catch

* mismatched parens/levels
  - made fancier by detecting which type of bracket was mismatched.
* mismatched string delimiters `done`
  - multiline strings are allowed, so this is just a matter of checking whether in string context at the end of the parsing.
