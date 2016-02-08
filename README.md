# S-Julia - s-expression to julia convertor.

## Overview

Goal: Taking the syntax of clojure (or something close enough) and
translating it to a julia `Expr` object. This shouldn't be
hard to do since Julia has a nice syntax already set up for this purpose
(the `Expr` objects)!

Then, look into doing julia -> clojure syntax. This may not be the cleanest,
since Julia's reader tends to aggressively wrap things in blocks (ie., `do`
from clojure), but it should still work. Of course, not everything in julia
can be transformed to a clojure expression, but given that the primary purpose
of this translation is to translate back from translated s-expressions (i.e,
when macroexpanding) it shouldn't be a problem to only support the limited
amount of things that are available in clojure as special forms.

Final goal - use this to do a `macroexpand` operation on the input clj syntax.
Basically, process all user-defined macros and output the resultant program,
but back to clojure syntax.
This would be useful for things like wispjs, where the transpiler is fully
operational, but the macro system sucks. You can write some macros, macroexpand
using this Julia module, then pass the resulting s-exprs through wispjs and
get a js output, all without invoking the horrible infrastructure around
clojurescript.

Effectively, this is just the **reader** portion of implementing a lisp - Julia
does everything else using its inbuilt mechanisms.

## Syntax Documentation

### Atoms

* `nil` translates to julia's `nothing`. They work exactly the same.
* `true` -> `true` and `false` -> `false`. No surprises at all there.
* `number` constants compile to either `Int64` or `Float64` types.
  * rational constants also supported, so `3/5` -> `3//5` in Julia.
* `character` any atom starting with a `\` is a character.
  * `\newline`, `\space`, `\tab`, `\formfeed`, `\backspace`, `\return` for escapes
  * unicode/octal support still needs to be handled.
  * non-strict, giving a longer literal silently just gives you the
    first character right now. This is probably not the best long-term strategy.
    Eg, `\xyz` -> `\x`
* `string` is any sequence of characters inside double quotes.
  * multiline strings are allowed, but padding is not subtracted (yet).
* `keyword` basically a symbol that starts with a `:`. In julia, these are confusingly called symbols, and symbols are called variables.
  * keywords cannot have a / or . in them anywhere.
  * in clojure keywords with two colons are resolved in the current namespace,
    that behavior is not the same here. Everything just compiles to a normal
    symbol in julia, so no namespacing. There are probably issues here, I just
    don't know what they are.
* `symbol` which is any identifier for a variable.
  * any `/` or `.` character is converted to a `.` in julia. Eg, `module/function`
    becomes `module.function` as an identifier. This should be relatively
    consistent with clojure semantics.
  * clojure is more lenient about symbol characters than julia. In order to get
    around this limitation, the default is to output unicode characters
    where regular ones won't suffice. so `*+?!-_':><` are all allowed inside a
    symbol.
    * TODO make the option to use escaped ascii-only names available. (ugly,
      but avoids having to use unicode, which is a pain depending on how your
      unicode extension is defined).
    * `::` in a symbol identifier compiles to a type. It's an error to have more
      than one of these in a symbol. eg, `x::Int` compiles to `(:: x Int)`
  * `@` is not allowed as part of a symbol name (anywhere, as of now) because
    it conflicts with julia's macro semantics. Please also note that `@`
    does not mean deref! That's a huge difference from Clojure proper.

### Collections

* `(a b c)` a list - if not quoted, it's evaluated and transpiled.
  * quoted lists evaluate to vectors, as of now.
* `[a b c]` a vector - transpiles to a julia array as well.
* `{a b c d}` a map - transpiles to a julia `Dict(a => b, c=> d)` form.
* TODO adding a tuple form. for now `(tuple a b c)` works.
* TODO sets, which can map to `Set()` in julia.

### Julia Special Forms

* `and`/`&&` (what you expect this to be) - needs to be a special form because
  of short circuiting. Julia defines the `and` and `or` forms this way on purpose.
* `or`/`||` (again, what you expect), see above.
* `(:: x Int)` -> `x::Int` The `::` form defines types.
  * only useful for function and type defintions.
* TODO `(curly Array Int64)` -> `Array{Int64}` will allow parameterized types.
* `(.b a x y)` -> `a.b(x,y)` is the dot call form.
* `(. a b c d)` -> `a.b.c.d` is the dot access form.
  * note that `((. a b) x y)` is equivalent to `(.b a x y)`.

### Special Forms

* `()` or empty list.
  * For now, this compiles to an empty array. In some lisps this is equivalent
    to nil (eg Common Lisp) but in Clojure it's not, so I'm following that
    convention.
* `(do exprs...)` does each expression and returns the results of the last one.
* `(if test true-case false-case?)` standard if, evaluates form #2 and branches.
* `(let [var1 value1 var2 value2...] exprs...)` binds pairs of variables to their values, then evaluates exprs in an implicit `do`.
* `(fn name? [params...] exprs...)` defines a function.
  * a function with no name and only one expr in the body will be converted to
    a `->` form. Eg: `(fn [x] x)` -> `(x) -> x`.
* `(defn name docstring? [params...] exprs...)` named defined function.
  * docstrings are ignored right now.
* `(def var expr)` defines a variable.
* `throw` is a function already in julia, so there's no special form dedicated to it.
* `include` is a function already in julia, so there's no dedicated special
  form for it.

* TODOS
  * loop/recur (this doesn't have a julia equivalent),
  * try/catch/finally
  * for vars in expr do... (useful for lazy iterators)
  * destructuring and rest param like `(fn [& rest])`
  * `defmulti` and related (does this even mean anything given julia's
    multiple-dispatch?)
  * `deftype` -> `type` in Julia.
  * `module` -> should be able to define a module in julia
  * `import` -> import statement.
  * `(@macro)`-> `macrocall` which is different from normal function call;
     Expr(:macrocall) instead of Expr(:call). It needs to be passed the dumped
     s-expression itself, not the read-in s-expression.

### Macro Forms

* `defmacro` defines a macro, as expected.
  * The way that macros work right now is that the macro definition is passed
    a *clojure* s-expression to work with. This is not the same as being passed
    a julia equivalent.
  * the macro output should again be a clojure expression, which has to be
    translated by the reader into a julia expression. This means that whatever
    program you write has to include the reader module of this project in order
    to produce the desired output.
  * Every macro will end in a call to Reader.read() which will translate the
    expression back to julia's native AST.
* `quote` or `'` gives a literal list of the following expression.
  * The quote form doesn't properly escape symbols yet. Eg, `'x` is equal to `:x`
    in Julia, but in order to stop the gensym pass from running you actually have
    to  do `esc(:x)` to get the equivalent. I'm unclear as of yet how the
    translation should work to get the desired results, so
    right now `quote` and `syntax-quote` do the same thing, which needs to be
    changed.
  * you *can* get around this yourself by putting esc calls in the right places,
    it will compile down to a function call in the code.
* `syntax-quote` or backtick character. the `:()` quoting form in julia is
  actually a syntax quote. It also has an auto-gensym (which can be a pain to get
  around if you want to return the original name without obfuscation).
* `unquote` or `~` is `$` in julia inside expressions. It should evaluate the
  variable that's given to the macro and use the evaluated value.
* `unquote-splice` or `~@` unquotes, and also expands the form by one layer
  into the form that's being returned. Ie, `(f ~@x)` is the same as
  `f($(x...))` in julia.



## Task List/Implementation Plan

### JL->CLJ Parser `parser.jl`
Takes in a file full of forms and returns an object (a julia array) that
contains the tree structure of the form.

#### Tokenize
The tokenizer is designed to take a raw string and split it into tokens that
are recognized by the parser. Clojure syntax has pretty simple tokenization,
so it's been implemented directly as a small state machine inside a while loop.

The only error checking here is for unclosed strings. Parens are handled by the
parser functions.

The tokenizer also returns metadata (right now, just the positions of each
token in the file for proper error reporting.)

**Things the tokenizer does:**

* Split () enclosing operations (and strings) `done`
* Ignore comments `done`
  * remove all ranges that look like `; .... \n` from the input file.
    It's possible to be fancier with this by generating a (comment "string")
    form but then it would be necessary to somehow eval this into an actual
    julia comment through it's s-expression syntax, which doesn't seem possible
    as of now. Eg, `:(#1)` just confuses the reader (it thinks the paren never
    closes).
* Treat `,` like whitespace `done`
* Reader macro special character combos (',\`,~,~@,#) `done`
* Character Literals `done`
* Line/Colno output (in metadata) `done`
* Catch unclosed quotation marks. `done`

**TODOS**

* Docstring mapping
  * There's a larger issue of mapping docstrings, which seems like it's not
    going to be possible. Currently julia's s-expression system chokes on
    docstrings followed by definitions (eg, functions).
    The only possible workaround is dropping a docstring inside a function (this
    is how clojure's syntax natively defines things anyway), except it ultimately
    compiles down to a single quoted string, not a triple quoted string. Note that
    this can't be worked around because there's no docstring function or any other
    way to hint to julia that docstrings are separate from regular strings.

#### Parser

Reads macro forms and list/vector/map forms separately and outputs them in a
standard s-expr format for the reader. The parser is actually pretty
straightforward now that it's been decomposed from the tokenizer.


** Handled ERRORS **

* mismatched parens/levels `done`
  - made fancier by detecting which type of bracket was mismatched.
* mismatched string delimiters `done`
  - multiline strings are allowed, so this is just a matter of checking whether in string context at the end of the parsing.



### CLJ->JL Reader (`read` function in reader.jl)

#### Atoms

* true, false, nil `done`
* numbers (int, float) `done`
* basic strings `done`
  * unescaping characters in strings `done, partially`
  * dispatch strings (r"" s"" b"" etc) TODO (you can still get this functionality
    manually by eg `(@r_str "string")`)
* basic char `done`
  * unicode/octal/hex characters still remaining
* keywords `done`
* symbols `done`
  * there are a lot of finicky little problems with symbols, chances are there
    are bugs somewhere in there.

#### Literals

* maps `done`
* vectors `done`

#### Special Forms

##### if,do,let,fn/defn,quote,def `done`

These are all pretty basic. You check for the head of the expression and
then accordingly build the right Julia Expr object.
It's gotten far enough to parse `testprograms/02-isolated-specialforms.clj`
which contains a few tricks. It can probably even do more than that, since
only if/let/fn/def are tested there.


##### and/&& and or/|| `done`
Julia makes these special forms.

##### . and :: `done`
. call form (i.e `(.x s)` -> `s.x()`) and :: type form `(:: x Int ) -> x::Int`.
Note that symbol reading allows you to just do `x::Int` directly and it will
be parsed the right way as well.

The type thing only works at binding sites (`let`, `fn` etc). Then again,
that makes sense - there's nowhere else that you need to declare types of things
anyway.

##### docstrings

In a `def...` type form only, eg `def`, `defn`, `deftype` etc.

Can look like:
```clojure
(defn f
  """ docstring goes here
  """
  [x] x)

(defn f [x]
  """ docstring goes here """
  x)
```

##### Replicating comments/whitespace across files

Right now, you get a strict two blank lines in between definitions.
You also don't get any of the comments replicated.

The comments part might be unworkable, since the comments are ignored completely
when reading the program in. The only way around this is to define a comment
special form and then have the reader parse that. Expr(:comment) isn't a native
Julia concept, so it will have to be manually overridden in the show function.

One stopgap fix possible is that if a line is ONLY a comment (nothing else) that
can be directly translated when reading in the file inside the final commandline
script that gets written. All that would have to change is that `;` is
translated to `#`, and only the lines in the middle of comments are passed to
the transpiler.

##### Multi Arity Functions

In Julia you can already do this by defining a function twice.
Combined with the ability to define types, I'm not so worried about this one.
However, technically I should also support the

```clojure
(def f
  ([x] 1)
  ([x y] 2))
```

syntax. Julia's function dipatch is actually a lot more comprehensive than even
Clojure's rather lenient version, since it dispatches based on all arguments
(I suppose only workable because it's compiled.).

##### Deftype

Julia's type system is more like a struct. This shouldn't be hard to do
as a special form, especially since you can define types.

```clojure
(deftype X [Y]
  a::Int
  b::AbstractString)
```
becomes

```julia
type X <: Y
  a::Int
  b::AbstractString
end
```

#### Defmacro

Macro definition is the same as function definition, with the caveat that the
output of the macro definition has to be wrapped in a call to `Reader.read` from
this project for it to output a proper julia expression.

### CLJ->JL Transpiler `transpiler.jl`

The job of the transpiler is to wrap the parser/reader and control the output.
Right now, printing julia works very well, except for printing macro related
symbols.
Macro definition forms have been fixed, but the unquote form does not want to
transpile well.
Regardless, the outputted code is correct and will run the way you expect. The
macro definitions will just look slightly ugly.

The same is true of macro calls, since they operate on the raw s-expression.
They can look very ugly (especially until Julia 0.5 goes through and there is
no longer a need to write `Any[]` in front of each array.)

### JL->CLJ Reader `cljreader.jl`

Now, it's time to go from Julia to Clojure. Thankfully we don't need a parse
function, that's already provided by julia itself. However, we do need to
write the reader function to understand all the special forms... in the reverse
direction.

This is made further complicated by the fact that julia will aggressively add
metadata and block (`begin ... end`) expressions around whatever it really feels
like, and it'll be part of the job of the reader not to output `do` statements
everywhere.

One more final problem is creating line breaks that make sense and formatting
the code. Julia somehow does this already for its own code. It shouldn't be too
hard so long as I follow some rules about what things should be/not be linebroken.
The issue is that it may not match *your* rules about how to format the code.
The alternative is outputting one-liners for every form, no matter how complex,
so any solution is probably better than no solution.

####ALL TODO

* write an equivalent read function that works on the `Meta.show_sexpr()` output
* Formatting Rules
  * A function is only on one line if it fits (with indentation) under 80 chars.
  * If the function name is followed immediately by one or more atoms, then
    do NOT linebreak those atoms. For example, `(partition 2 ...)` should have
    2 on the same line as `partition`.
