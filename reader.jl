module Reader

include("errors.jl")
using .Errors

include("parser.jl")
using .Parser: DICTID, VECID

export read


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

    # and/&& (julia makes these special forms, not function calls...)
    if sexp[1] in ("&&", "and")
      return Expr(:&&, map(read, sexp[2:end])...)
    end

    ## or/|| (julia makes these special forms too.)
    if sexp[1] in ("||", "or")
      return Expr(:||, map(read, sexp[2:end])...)
    end

    # MACRO special characters, ',`,~,~@

    # quote
    # inside a macro expression, you can do esc(:x) to mean 'x, and :x to mean
    # `x, but outside of that they both are :x, which is a wierd quirk of
    # julia macros.
    if sexp[1] in ("'", "`", "quote")
      if length(sexp) != 2
        # can only quote one form at a time.
        throw(InvalidFormCountError(0,0,"quote",sexp,
                                    "2 forms", "$(length(sexp))"))
      end
      return Expr(:quote, read(sexp[2]))
    end

    if sexp[1] == "~"
      if length(sexp) != 2
        # can only quote one form at a time.
        throw(InvalidFormCountError(0,0,"unquote",sexp,
                                    "2 forms", "$(length(sexp))"))
      end
      return Expr(:$, read(sexp[2]))
    end

    if sexp[1] == "~@"
      if length(sexp) != 2
        # can only quote one form at a time.
        throw(InvalidFormCountError(0,0,"unquote",sexp,
                                    "2 forms", "$(length(sexp))"))
      end
      return Expr(:$, Expr(:tuple, Expr(:..., read(sexp[2]))))
    end

    # def (variable assignment)
    if sexp[1] == "def"
      if length(sexp) != 3
        throw(InvalidFormCountError(0,0,"def",sexp,
                                    "3 forms", "$(length(sexp))"))
      end
      return Expr(:(=), readsym(sexp[2]), read(sexp[3]))
    end

    # if
    if sexp[1] == "if"
      if !(length(sexp) in Int64[3,4])
        throw(InvalidFormCountError(0,0,"if",sexp,
                                    "3 or 4 forms", "$(length(sexp))"))
      end
      # there's no "block" here because we only deal with ternary if.
      # Ie. (if true 0 1) -> :(true ? 0 : 1) in Julia.

      # can optionally have else
      if length(sexp) == 3
        return Expr(:if, read(sexp[2]), read(sexp[3]))
      else
        return Expr(:if, read(sexp[2]), read(sexp[3]), read(sexp[4]))
      end
    end

    # do
    if sexp[1] == "do"
      return Expr(:block, map(read, sexp[2:end])...)
    end

    # let
    if sexp[1] == "let"
      if length(sexp) < 3
        throw(InvalidFormCountError(meta[1]...,"let",sexp,
                                    "at least 3 forms","$(length(sexp))"))
      end
      # TODO more error checking - make sure that sexp[2] is a vector,
      # and that it has an even number of forms.
      if !isa(sexp[2], Array)
        throw()
      end
      if sexp[2][1] != "::__vec__::"
      end
      if length(sexp[2]) % 2 != 1
      end


      # looks like (let [vars] body), but julia does it backwards.
      return Expr(:let,
                  # body goes here
                  Expr(:block, map(read, sexp[3:end])...),
                  # bindings go here
                  map(x->Expr(:(=), readsym(x[1]), read(x[2])),
                      partition(2, sexp[2][2:end]))...)
    end

    # TODO need more error checking here - make sure we have vectors where
    # needed and such.
    # fn (the same thing in julia)
    if sexp[1] == "fn"
      if isa(sexp[2], Array)
        # (fn [x] body)
        # small optimization. If it's an anonymous function with only one
        # term in the body, replace with -> syntax.
        if isa(sexp[2], Array)
          return Expr(:->, Expr(:tuple, map(readsym, sexp[2][2:end])...),
                      read(sexp[3]))
        else
          return Expr(:function, Expr(:tuple, map(readsym, sexp[2][2:end])...),
                      Expr(:block, map(read, sexp[3:end])...))
        end
      else
        # (fn name [x] body)
        return Expr(:function, Expr(:call, readsym(sexp[2]),
                                    map(readsym, sexp[3][2:end])...),
                    Expr(:block, map(read, sexp[4:end])...))
      end
    end

    # defn, in julia doing `function x(y) y end` defines it too, so it's just
    # the last part from above
    if sexp[1] == "defn"
      if length(sexp) < 4
        throw(InvalidFormCountError(0,0,sexp,
                                    "at least 4 forms","$(length(sexp))"))
      end
      # (defn name [x] body)
      return Expr(:function, Expr(:call, readsym(sexp[2]),
                                  map(readsym, sexp[3][2:end])...),
                  Expr(:block, map(read, sexp[4:end])...))
      # TODO add ability to deal with docstrings.
    end


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

    # Julia special forms.
    # typing assert form
    if sexp[1] == "::"
      return Expr(:(::), map(read, sexp[2:end])...)
    end

    # dot call form -
    if sexp[1][1] == '.'
      # first, if it's like (.x y), this is y.x()
      if length(sexp[1]) > 1
        return Expr(:call, Expr(:., read(sexp[2]),
                                QuoteNode(readsym(sexp[1][2:end]))),
                    map(read, sexp[3:end])...)
        # second, if it's (. x y z a b...) this is x.y.z.a.b. ...
      else
        e = readsym(sexp[end])
        for sym in reverse(sexp[2:end-1])
          e = Expr(:., readsym(sym), QuoteNode(e))
        end
        return e
      end
    end

    # if none of these things, it's just a regular function call.
    # in julia syntax, this is
    return Expr(:call, readsym(sexp[1]), map(read, sexp[2:end])...)
  else
    # Atoms

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
    # :[symbol]* -> keyword (symbol in julia, like :(:symbol))
    elseif sexp[1] == ':'
      if contains(sexp, ".") || contains(sexp, "/")
        throw(InvalidTokenError(0,0,sexp))
      end
      return symbol(sexp[2:end])
    # [symbol]* -> symbol (variable in julia, like :symbol)
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
eg: *+?!-_':>< (: has to be non-repeating.)
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
* - -> \div (fancy looking bordered -, basically) ÷
* ' -> \prime ′ (Who uses a quote in the name of a variable?)
* < -> \epsilon ϵ (most < looking characters aren't allowed as part of a variable)
* > -> \backepsilon ϶

Alternatively, you could convert it to a messy escaped ASCII version, if
desired.

* ! is given
* _ -> __ (needs to be escaped)
* * -> _s
* ? -> _q
* + -> _p
* - -> _d
* ' -> _a
* > -> _g
* < -> _l

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
    str = replace(str, "-", "÷")
    str = replace(str, "'", "′")
    str = replace(str, "<", "ϵ")
    str = replace(str, ">", "϶")
  else
    str = replace(form, "_" ,"__")
    str = replace(str, "*" ,"_s")
    str = replace(str, "?" ,"_q")
    str = replace(str, "+" ,"_p")
    str = replace(str, "-" ,"_d")
    str = replace(str, "'" ,"_a")
    str = replace(str, "<", "_l")
    str = replace(str, ">", "_g")
  end

  # symbol must begin with a -,_,or a-zA-Z character.
  if match(r"^(?:(?:[-_][a-zA-Z])|[a-zA-Z])", form) == nothing
    throw(InvalidTokenError(0,0,form))
  end

  # extract type
  symtype = split(str, "::")
  # Note that this is strict parsing.
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
    e = Expr(:., symbol(p), QuoteNode(e))
  end

  if length(symtype) > 1
    return Expr(:(::), e, eval(readsym(t)))
  else
    return e
  end
end

"""
Translates Clojure style builtins to Julia's builtins.
This is also possible to do in s-expression syntax itself rather than building
it into the compiler, but you then have to include that setup file every time
you go to compile s-expression code. While that allows for maximum flexibility,
there are some (limited) things which are ubiquitous enough to be directly
inlined here, so that there's no library headache.

In the future, this might be expanded to include a lot more than just basic
operators, but the limitation is that julia has the function as a builtin.

Note that Julia's proper builtins are still overshadowed and available, so
even though Clojure only defines "str", "str" and "string" will both be
available and do the same thing.

BTW, this also means that all of Julia's builtins are available to the
s-expression frontend.
"""
function readbuiltin(str)

  # equality is a single = in clojure, but == in julia.
  if str == "=" return :(==) end
  if str == "not" return :! end
  if str == "not=" return :!= end

  if str == "mod" return :% end
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

end #module


if length(ARGS) > 0 && ARGS[1] in ("--run", "-r")
  include("parser.jl")
  eval(:(importall Parser))
  eval(:(importall Reader))
  ast,meta = Parser.parsesexp(readall(STDIN))
  for form in ast
    println(Reader.read(form))
    println("\n")
  end
end



