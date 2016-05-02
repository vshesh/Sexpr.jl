# S-Julia - s-expression to julia convertor.

<span>
<img src="https://travis-ci.org/vshesh/Sexpr.jl.svg?branch=master"/>
<img src="https://coveralls.io/repos/github/vshesh/Sexpr.jl/badge.svg?branch=master"/>
</span>

## Quickstart

``` {.bash}
> Pkg.clone("https://github.com/vshesh/Sexpr.jl.git")

$ julia -e 'import Sexpr; Sexpr.main()' --
usage: Sexpr.jl [-i] [-c] [-l LINES] [-o OUTPUT] [-e EXTENSION] [-h]
               [files...]
A program to port clojure-like s-expression syntax to and from
julia. By default, this program takes clojure syntax and outputs
the julia version. Use -i to flip direction.

positional arguments:
  files                 If given one file and no output directory,
                        will dump to stdout. If given a directory or
                        multiple files, eg "sjulia file1 dir file2",
                        an output directory must be specified with
                        -o/--output where the files will go.
optional arguments:
  -i, --invert          take julia code and print out s-expression
                        code instead
  -c, --cat             cat all the input from STDIN rather than read
                        from file. Ignores all positional args to the
                        program.
  -l, --lines LINES     how many blank lines should exist between top
                        level forms, default 1 (type: Int64, default:
                        1)
  -o, --output OUTPUT   where to write out files if there are multiple
                        positional arguments to the file. If this is
                        empty, and there are >1 argument, the program
                        will throw an error.
  -e, --extension EXTENSION
                        add an extension that qualifies as a lisp file
                        (can use multiple times). Defaults: clj, cljs,
                        cl, lisp, wisp, hy.
  -h, --help            show this help message and exit
```

``` {.bash}
$ julia -e 'import Sexpr; Sexpr.main()' -- -o test/output/ test/programs/
# will transpile all .clj files in test/programs and dump them into test/output.
```

## Overview

This project aims to make s-expression syntax interoperable with julia's
own Expr objects.

If you've seen LispSyntax.jl, it's a similar idea, but IMHO
this project does a bit more, such as allow you to transpile file->file rather than just read in a program, and also transpile back, so you can convert your julia files (minus a few special forms that aren't supported yet) into clojure syntax. This makes it possible to go from julia to python (again, not that anyone needed another route b/c pycall) via Hylang, or to JS via WispJS. The benefit here is that the awkward macro syntax in both of those languages is avoided (Hy necessitates wrapping everything in HyModel objects yourself, which is ridiculous, and WispJS's module system is broken, because it is Javascript, so resolving variable names is not working properly).

The final goal is to use interoperability to do a `macroexpand` operation on the input clj syntax. So you would be able to give a folder of clj files, and a temp folder with jl files would be created, then each file would be read in and macroexpanded, converted back to clj syntax, and written out to a third folder. Unfortunately, it's necessary to write the jl files out as an intermediary step, because they need to be able to find each other to resolve imports.
Alternatively, you could write the clj files as jl files with the macro `@clj_str`, but that makes your whole file a string, which breaks most syntax highlighters, which can be annoying.

I know that you're probably thinking "why?" and it was mostly a project for me to learn Julia and muck around with its internals. I learned quite a bit, so mission accomplished! CLJS has self-hosting now, which means that they will hopefully have a js-only package soon. However, dealing with google closure compiler and leiningen's java/jvm dependencies are a larger problem to be solved, and until then, I still consider it unwieldy, so there's still some practical use to
be had here.

Effectively, this is just the **reader** portion of implementing a lisp - Julia does everything else using its inbuilt mechanisms.

## Syntax Overview

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
    * `::` in a symbol identifier compiles to a type. eg, `x::Int` compiles to `(:: x Int)`
    * `::T1::T2` compiles to a union like `x::T1::T2` -> `(:: x T1 T2)`

### Collections

* `'(a b c)` a list - if not quoted, it's evaluated and transpiled.
  * quoted lists evaluate to tuples, as of now.
* `[a b c]` a vector - transpiles to a julia array.
* `{a b c d}` a map - transpiles to a julia `Dict(a => b, c=> d)` form.
* TODO `#{a b c}` a set, which can map to `Set()` in julia.

### Julia Special Forms

* Short Circuit
  * `and`/`&&` (what you expect this to be) - needs to be a special form because
    of short circuiting. Julia defines the `and` and `or` forms this way on purpose.
  * `or`/`||` (again, what you expect), see above.
* `x[i]` family (getting/setting/slicing arrays)
  * `(aget x 1)` -> `Expr(:ref, :x, 1)` -> `x[1]`.
  * `(aget x 1 2 4 5)` -> `Expr(:ref, :x, 1, 2, 4, 5)` -> `x[1, 2, 4, 5]`
  * `(aget x (: 1 3))` -> `x[1:3]`
  * `(aget x (: 6))` -> `x[6:end]` (preferred)
  * `(aget x (: 6 :end))` -> `x[6:end]` (not preferred)
* Typing
  * `(:: x Int)` -> `x::Int` The `::` form defines types.
    * `(:: x Int In64)` -> `x::Union{Int, Int64}` there's auto-union if many types are defined.
    * only useful for function and type defintions.
  * `(curly Array Int64)` -> `Array{Int64}` will allow parameterized types.
  * `(.b a x y)` -> `a.b(x,y)` is the dot call form.
  * `(. a b c d)` -> `a.b.c.d` is the dot access form.
    * note that `((. a b) x y)` is equivalent to `(.b a x y)`.
* Modules and Import
  * `(module M ... end)` creates a module.
    This is visually annoying since you indent your whole file by two spaces
    just for this call to module, however I haven't figured out any better way
    to do this - the other option is to make `#module M` a special hash dispatch
    that wraps the whole file but... meh, I don't consider this a high enough
    priority.
  * `(import|using X y z a b)` contrary to my expectations, this will give you
    `import X.y.a.b`. There will be a separate import statement for each
    function/file you want to use.
    * TODO make this cartesian productable, so `(import X [y z a])` will expand
      to `import X.y; import X.z; import X.a` instead. This should shorten the
      writing. Ideally should make this a system macro (in a system.clj file
      that I define) and call it `import*` or something.
  * `(export a b c)` -> `export a, b, c`.
    It makes sense from julia's point of view, since modules
    are flat things, and you only ever have one level of definitions to export.
    
### Special Forms

* `()`/`'()` or empty list.
  * For now, this compiles to an empty tuple. In some lisps this is equivalent
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

### Macro Forms

* `(@m x y z)` how to call a macro - prepend it's name with `@`. There is
  unfortunately no way around this, since julia requires this distinction and
  for me to resolve what things are macros without it
  would involve writing an entire compiler.
  To keep it simple, I'm leaving this requirement in place.
  * TODO Since `@x` means deref in clojure, I might choose to use a different
    symbol to denote macrocall in the future. maybe `μ` or something.
    Another idea is abusing # dispatch so `#macro (html [:div "helloworld"])``
    calls the next form as a macro rather than a regular function.
    The hash dispatch one seems worse, though.
* `defmacro` defines a macro, as expected.
  * The way that macros work right now is that the macro definition is passed
    a *clojure* s-expression to work with. This is not the same as being passed
    a julia equivalent.
  * the macro output should again be a clojure expression, which has to be
    translated by the reader into a julia expression. This means that whatever
    program you write has to include the reader module of this project in order
    to produce the desired output.
  * Every macro will end in a call to `Sexpr.rehydrate()` which will translate the
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
  `:(f($x...))` in julia.
