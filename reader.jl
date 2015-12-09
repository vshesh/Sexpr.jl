module Reader

export VECID, DICTID
export parsesexp, extractsexp, read
export UnclosedError, MismatchedError, ExtraError, InvalidTokenError

VECID = "::__vec__::"
DICTID = "::__dict__::"
PARENS = Dict(')' => '(', ']' => '[', '}' => '{')

"""
Reader error types.
"""
type ExtraError <: Exception
  lineno::Int
  colno::Int
  c::Char
end
Base.showerror(io::IO, e::ExtraError) =
  print(io, "$(typeof(e)) at line $(e.lineno):$(e.colno), extra $(e.c) found.")

type MismatchedError <: Exception
  lineno::Int
  colno::Int
  expected::Char
  found::Char
end
Base.showerror(io::IO, e::MismatchedError) =
  print(io, "$(typeof(e)) at line $(e.lineno):$(e.colno) found mismatch, ",
            "expected to close $(e.expected), found $(e.found) instead")

type UnclosedError <: Exception
  lineno::Int
  colno::Int
  c::Char
end
Base.showerror(io::IO, e::UnclosedError) =
  print(io, "$(typeof(e)) at line $(e.lineno):$(e.colno) found unclosed $(e.c)")

# If someone types garbage as a symbol, this error will come up.
type InvalidTokenError <: Exception
  lineno::Int
  colno::Int
  token::AbstractString
end
Base.showerror(io::IO, e::InvalidTokenError) =
  print(io, "$(typeof(e)) at line $(e.lineno):$(e.colno), ",
            "invalid token found: $(e.token)")

type InvalidFormCountError <: Exception
  lineno::Int
  colno::Int
  kind::AbstractString
  form::AbstractString
  expected::AbstractString
  found::AbstractString
end
Base.showerror(io::IO, e::InvalidFormCountError) =
  print(io, "At line $(lineno):$(colno), $(e.kind) should have $(e.expected), ",
            "found $(e.found) instead: $(e.form)")

type WrappedException <: Exception
  lineno::Int
  colno::Int
  e::Exception
  message::AbstractString
end
Base.showerror(io::IO, e::WrappedException) =
  print(io, "$(typeof(e)) at line $(lineno):$(colno): $(e.message)")

"""
Checks to make sure the token is valid by Clojure standards.
Note that this is just a TOKEN identifier, it doesn't check for any semantics.
Ie., you can define a nonsensical character literal like `\character` which
will be read as a token, but needs to be semantically verified with
something that knows more about what is going on.
"""
function validtoken(token)
  # taken from https://github.com/kanaka/mal/blob/master/process/guide.md
  # which is a guide on how to write a clojure looking lisp.
  ismatch(r"(~@|[\[\]{}()'`~^@]|\"(?:\\.|[^\\\"])*\"|;.*|[^\s\[\]{}('\"`,;)]*)",
          token)
end

"""
Intended to parse any number of s-expression forms.
Eg, given something like `(+ 1 (+ 2 3))`,
return `[["+", "1", ["+", "2", "3"]]]`

With multiple forms like
```clojure
(defn identity [x] x)
(defn constf [c] (fn [] c))
```
You should get an ouptut like

```julia
[
 ["defn", "identity", [VECID, "x"] "x"],
 ["defn", "constf", [VECID, "c"], ["fn", [VECID], "c"]]
]
```

As you can see, vectors are converted into lists that start with the
`VECID` special term (defined above) and equivalently map literals
such as `{1 2 3 4}` are parsed into lists that have `DICTID` as their heads.
This allows them to be specially parsed/handled by the analyzer and not clobber
other concepts, like actually having a keyword called `:vect` or `:dict`

Ultimately `VECID` and `DICTID` are some string, so I'm hoping that they are
just bizarre enough that no one would ever use them in an actual use case.

This is supposed to be a comprehensive lexer for all clojure-like syntax.
See reader-tests.jl for some basic tests that show what is and is not allowed.
"""
function parsesexp(str::AbstractString)

  function endword(sexp, lineno, colno, word)
    if !validtoken(word)
      throw(InvalidTokenError(lineno, colno, token))
    end
    if length(word) > 0
      push!(sexp[end], word)
      ""
    else
      word
    end
  end

  function parenmatch!(lineno, colno, levels, c)
    if length(levels) < 1
      throw(ExtraError(lineno, colno, c))
    end
    popen = pop!(levels)
    if popen != PARENS[c]
      throw(MismatchedError(lineno, colno, popen, c))
    end
  end

  sexp = []
  push!(sexp, [])

  levels = Char[]
  lineno = 1
  colno = 1

  word = ""
  in_str = false
  in_comment = false

  for i in collect(range(1,length(str)))
    c = str[i]
    if c == '\n'
      lineno += 1
      colno = 1
    else
      colno += 1
    end

    # Only one of these will be true at one time
    if c == '"' && (i == 1 || str[i-1] != '\\')
      in_str = !in_str
      # if we just started a string, end the previous word
      if in_str
        word = endword(sexp, lineno, colno, word)
      end
    end
    if !in_str && c == ';'
      in_comment = true
    end
    if in_comment && c == '\n'
      in_comment = false
    end

    # list push/pop operations, and symbol reading
    if !in_str && !in_comment
      if c == ',' continue end
      if c == '('
        push!(sexp, [])
        push!(levels, c)
      elseif c == '['
        push!(sexp, [])
        push!(sexp[end], VECID)
        push!(levels, c)
      elseif c == '{'
        push!(sexp, [])
        push!(sexp[end], DICTID)
        push!(levels, c)
      elseif c in (')', ']', '}')
        parenmatch!(lineno, colno, levels, c)
        word = endword(sexp, lineno, colno, word)
        t = pop!(sexp)
        push!(sexp[end], t)

      elseif c in (' ', '\n', '\t')
        word = endword(sexp, lineno, colno, word)
      elseif c == '\\'
        # here it's a new character block
        word = endword(sexp, lineno, colno, word)
        word = string(word, c)
      else
        word = string(word, c)
      end
    end
    if !in_comment && in_str
      word = string(word,c)
    end
  end

  # if length(word) > 0 here, then there is some form OUTSIDE the final
  # close paren that is just an atom, and we should drop that into the
  # sexpr too.
  if length(word) > 0
    endword(sexp, lineno, colno, word)
    word = ""
  end

  # basic context closing error checking
  if in_str
    throw(UnclosedError(lineno, colno, '"'))
  end

  if length(levels) > 0
    throw(UnclosedError(lineno, colno, pop!(levels)))
  end

  sexp[1]
end


"""
Converts a rich dict based representation of a sexp into an actual
Expression object.
"""
function extractsexp(sexp::Dict{Symbol,Any})
  expr = sexp[:sexp]
  if isa(expr, Array{Any})
    map(extractsexp, expr)
  else
    expr
  end
end

""" only works if length(xs) % n == 0"""
partition(n,x) = [x[i:min(i+n-1,length(x))] for i in 1:n:length(x)]

"""

TODO: Add a second sexp-like object that has line numbers in it, so that
error reporting actually makes sense.
"""
function read(sexp)
  if isa(sexp, Array)
    # Special forms
    # def

    # if
    # do
    # let
    # quote
    # fn
    # loop/recur? -> might do for instead as a special form

    # special julia-eque forms
    # for
    # try/catch
    # deftype -> type


    # Literals
    # map
    if sexp[1] == DICTID
      # MUST have pairs of operations
      if length(sexp) % 2 != 1
        # note that (DICTID, pair of operations) will always be an
        # odd number of forms
        throw(InvalidFormCountError(0,0,"map",sexp,
                                    "even number of forms",
                                    "$(length(sexp))"))
      end
      return Expr(:call, :Dict,
                  map(x -> Expr(:(=>), x...),
                      partition(2, map(read,sexp[2:end])))...)
    end
    # vector
    if sexp[1] == VECID
      return Expr(:vect, map(read, sexp[2:end])...)
    end

    # dot call form -
    if sexp[1][1] == '.'
      return Expr(:call, Expr(:., readsym(sexp[2]),
                          Expr(:quote, readsym(sexp[1][2:end]))),
                  map(read, sexp[3:end])...)
    end

    # if none of these things, it's just a regular function call.
    # in julia syntax, this is
    return Expr(:call, readsym(sexp[1]), map(read, sexp[2:end])...)
  else
    # Special reader macros
    # ' (quote)


    # Atoms

    # :[symbol]* -> keyword (symbol in julia, like :(:symbol))
    # [symbol]* -> symbol (variable in julia, like :symbol)
    if sexp == "nil"
      return nothing
    elseif sexp == "true"
      return true
    elseif sexp == "false"
      return false
    elseif isdigit(sexp[1]) || (sexp[1] == '-' && isdigit(sexp[2]))
      return readnumber(sexp)
    elseif sexp[1] == '"'
      #this should strip the '"' characters at both ends
      return unescape(sexp[2:end-1])
    elseif sexp[1] == '\\' && length(sexp) > 1
      return readchar(sexp)
    elseif sexp[1] == ':'
      return symbol(sexp[2:end])
    else
      # the base option is that we're dealing with a symbol.
      return readsym(sexp)
    end
  end
end


"""
The two special characters in a symbol are . and /
They amount to the same thing in Julia, so all we have to do is
split the string by those tokens and nest the "dot" form inside them.
In fact, you can never recover a slash in a symbol, since it just gets coerced
to a dot anyway. In general, s-expression julia shouldn't have any slashes
to begin with - there's no concept of a "namespace".

type support is done by allowing :: inside a symbol, eg
x::Int -> Expr(:(::), x, Int)
This is tricky because you have to evaluate the type symbol.
Also, :: can only occur once inside the symbol. Any more times and this will
throw an error.

Special symbols: clojure allows more than julia is capable of handling.
eg: *+?!-_': (: has to be non-repeating.)
of these, support for ! and _ comes out of the box.
We need a isomorphism from some clojure name to a julia name.
Of course, doing so would lead to some pretty ugly symbol names, so there's
a tradeoff between something readable and something that's backwards
transformable.
One thing to note is that julia allows unicode characters, so those might be
necessary to delineate special marks in the clojure name.
In fact, that makes for a pretty easy translation, using greek letters,
but it makes it an EXTREME pain in the ass to translate back to ascii clojure
type symbols (since unicode boundaries are not clean the way ASCII is).

* !,_ are given

* * -> \degree °
* ? -> \Elzglst ʔ
* + -> \textdoublepipe ǂ
* - -> \Xi (fancy looking bordered -, basically) Ξ
* ' -> \prime ′ (Who uses a quote in the name of a variable?)

Alternatively, you could convert it to a messy escaped ASCII version, if
desired.

* ! is given
* _ -> __ (needs to be escaped)
* * -> _s
* ? -> _q
* + -> _p
* - -> _d
* ' -> _a

This might be nice for situations where you're going to only macroexpand,
since it avoids unicode headaches. It would suck if you actually had to
go read the Julia code afterwards though. ASCII only mode is only useful if
you need ASCII compatability for some external reason.

Of course, adding sanitizing means we have to also know when we're dealing with
operators and make sure to exclude them from the sanitization process.
"""
function readsym(form, unicode=true)
  # Operators
  validops = string("^(?:",
                    #  (math) +, -, *, /, \, ^, %, //
                    "\\+|-|\\*|/|\\\\|\\^|%|(?://)",
                    #  (bitmath) ~, &, |, $, >>, <<, >>>
                    "|~|&|\\||\\\$|(?:>>)|(?:<<)|(?:>>>)",
                    # (comparison) ==, !=, <, >, <=, >=,
                    "|(?:==)|(?:!=)|<|>|(?:<=)|(?:>=)",
                    # (syntax) ., ::
                    "|\\.|(?:::)",
                    ")\$"
                    )
  if match(Regex(validops), form) != nothing
    return symbol(form)
  end

  b = readbuiltin(form)
  if b != nothing return b end

  # replace the non-julia symbol characters.
  if unicode
    str = replace(form, "*", "°")
    str = replace(str, "?", "ʔ")
    str = replace(str, "+", "ǂ")
    str = replace(str, "-", "Ξ")
    str = replace(str, "'", "′")
  else
    str = replace(form, "_" ,"__")
    str = replace(str, "*" ,"_s")
    str = replace(str, "?" ,"_q")
    str = replace(str, "+" ,"_p")
    str = replace(str, "-" ,"_d")
    str = replace(str, "'" ,"_a")
  end

  # symbol must begin with a -,_,or a-zA-Z character.
  if match(r"^(?:(?:[-_][a-zA-Z])|[a-zA-Z])", form) == nothing
    throw InvalidTokenError(0,0,form)
  end

  # extract type
  symtype = split(str, "::")
  # Note that this is a strict parsing thing.
  # We could just ignore everything after the second :: and beyond in the
  # symbol
  if length(symtype) > 2
    throw(InvalidTokenError(0,0,str))
  end

  s = symtype[1]
  if length(symtype) > 1
    t = symtype[2]
  end

  # now parse s for dots and slashes
  # the dotted name is built in reverse.
  parts = split(s, r"[./]")
  e = symbol(parts[end])
  for p in reverse(parts[1:end-1])
    e = Expr(:., symbol(p), Expr(:quote, e))
  end

  if length(symtype) > 1
    return Expr(:(::), e, eval(readsym(t)))
  else
    return e
  end
end

"""
Translates Clojure style builtins to Julia's builtins
Note that Julia's proper builtins are still overshadowed and available, so
even though Clojure only defines "str", "str" and "string" will both be
available and do the same thing.

BTW, this also means that all of Julia's builtins are available to the
s-expression frontend.
"""
function readbuiltin(str)

  # equality is a single = in clojure, but == in julia.
  if string == "=" return :(==) end
  if string == "not" return :! end
  if string == "not=" return :!= end

  if string == "mod" return :% end

  return nothing
end


function unescape(str)
  s = replace(str, "\\b", "\b")
  s = replace(s, "\\n", "\n")
  s = replace(s, "\\a", "\a")
  s = replace(s, "\\t", "\t")
  s = replace(s, "\\r", "\r")
  s = replace(s, "\\f", "\f")
  s = replace(s, "\\v", "\v")
  s = replace(s, "\\'", "'")
  s = replace(s, "\\\"", "\"")
  s = replace(s, "\\\\", "\\")

  # TODO add unicode support
  # TODO add hex char support
  # TODO add octal char support
  s
end

function readchar(str)
  unescape(str)[1]
end

function readnumber(str)
  # if it's just [0-9]* it's an integer
  if ismatch(r"^-?[0-9]+$", str)
    parse(Int, str)
  elseif ismatch(r"^-?[0-9]+r[0-9]+$", str)
    p = split(str,'r')
    try
      # it's possible to still have a malformatted number
      # this is an int with a specified radix.
      parse(Int, p[1], parse(Int,p[2]))
    catch a
      if isa(a, ArgumentError)
        throw(WrappedException(0,0,a))
      else
        rethrow(a)
      end
    end
  elseif ismatch(r"^-?[0-9]+(\.[0-9]+)([fe]-?[0-9]+)?$", str)
    try
      # it's possible to still have a malformatted number
      parse(Float64, str)
    catch a
      if isa(a, ArgumentError)
        throw(WrappedException(0,0,a))
      else
        rethrow(a)
      end
    end
  else
    throw(InvalidTokenError(0,0,str))
  end
end
end


if length(ARGS) > 0 && ARGS[1] == "--run"
  using Reader
  eval(:(
         for form in Reader.parsesexp(readall(STDIN))
           print(form)
           print(" => ")
           println(Reader.read(form))
         end
  ))
end



