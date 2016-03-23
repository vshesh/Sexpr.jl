module Reader

include("errors.jl")
using .Errors

include("parser.jl")
using .Parser: DICTID, VECID

include("util.jl")
using .Util: isform

export read


""" only works if length(xs) % n == 0"""
partition(n,x) = [x[i:min(i+n-1,length(x))] for i in 1:n:length(x)]


"""

"""
function read(sexp, meta)
  if isa(sexp, Tuple) || isa(sexp, Array)
    # empty array
    if length(sexp) == 0
      # () = '() != nil (in clojure, anyway. in lisp this is the same as nil)
      return Expr(:tuple)
    end

    # MACRO special characters, ',`,~,~@
    if sexp[1] in ("`","'","~","~@","quote")
      if length(sexp) != 2
        # can only macro character one form at a time.
        throw(InvalidFormCountError(meta[1]..., sexp[1], sexp,
                                    "2 forms", "$(length(sexp))"))
      end

      # quote
      # inside a macro expression, you can do esc(:x) to mean 'x, and :x to mean
      # `x, but outside of that they both are :x, which is a wierd quirk of
      # julia macros.
      if sexp[1] in ("'", "`", "quote")
        # TODO quote needs to be split to escape everything,
        # but `esc` is a complex beast in julia.
        if isform(sexp[2])
          return Expr(:tuple, map(read, sexp[2], meta[2])...)
        else
          return Expr(:quote, read(sexp[2], meta[2]))
        end

      elseif sexp[1] == "~"
        return Expr(:$, read(sexp[2], meta[2]))

      elseif sexp[1] == "~@"
        return Expr(:$, Expr(:tuple, Expr(:..., read(sexp[2], meta[2]))))
      end
    end


    # Special forms
    # do
    if sexp[1] == "do"
      return Expr(:block, map(read, sexp[2:end], meta[2:end])...)
    end

    # def (variable assignment)
    if sexp[1] == "def"
      if length(sexp) != 3
        throw(InvalidFormCountError(meta[1]...,"def",sexp,
                                    "3 forms", "$(length(sexp))"))
      end
      return Expr(:(=), readsym(sexp[2], meta[2]), read(sexp[3], meta[3]))
    end

    # if
    if sexp[1] == "if"
      if !(length(sexp) in Int[3,4])
        throw(InvalidFormCountError(meta[1]...,"if",sexp,
                                    "3 or 4 forms", "$(length(sexp))"))
      end
      # there's no "block" here because we only deal with ternary if.
      # Ie. (if true 0 1) -> :(true ? 0 : 1) in Julia.

      # can optionally have else
      if length(sexp) == 3
        return Expr(:if, read(sexp[2], meta[2]), read(sexp[3], meta[3]))
      else
        return Expr(:if,
                    read(sexp[2], meta[2]),
                    read(sexp[3], meta[3]),
                    read(sexp[4], meta[4]))
      end
    end

    # let
    if sexp[1] == "let"
      if length(sexp) < 2
        throw(InvalidFormCountError(meta[1]...,"let",sexp,
                                    "at least 2 forms","$(length(sexp))"))
      end
      # TODO more error checking - make sure that sexp[2] is a vector,
      # and that it has an even number of forms.
      if !isform(sexp[2])
        
      end
      if sexp[2][1] != VECID
        
      end
      # vector has even forms + one VECID, so it should have odd length
      if length(sexp[2]) % 2 != 1
        
      end


      # sexp looks like (let [vars] body), but julia does it backwards.
      return Expr(:let,
                  # body goes here
                  Expr(:block, map(read, sexp[3:end], meta[3:end])...),
                  # bindings go here
                  map(x->Expr(:(=), readsym(x[1]...), read(x[2]...)),
                      partition(2, collect(zip(sexp[2][2:end], meta[2][2:end]))))...)
    end

    if sexp[1] == "fn" || sexp[1] == "defn"
      return readfunc(sexp, meta)
    end

    # defmacro
    # same as defn, with two differences:
    # the head of the expr needs to be replaced with "macro" before returning.
    # the last form needs to be wrapped in a call to Reader.read.
    if sexp[1] == "defmacro"
      e = readfunc(sexp, meta)
      e.head = :macro
      # this should wrap the entire block
      e.args[end].args[end] = Expr(:call, :(Reader.read), e.args[end].args[end])
      return e
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
        throw(InvalidFormCountError(meta[1]...,"map",sexp,
                                    "even number of forms",
                                    "$(length(sexp))"))
      end
      return Expr(:call, :Dict,
                  map(x -> Expr(:(=>), x...),
                      partition(2, map(read,sexp[2:end], meta[2:end])))...)
    end
    # vector
    if sexp[1] == VECID
      return Expr(:vect, map(read, sexp[2:end], meta[2:end])...)
    end

    # Julia special forms.

    # and/&& (julia makes these special forms, not function calls...)
    if sexp[1] in ("&&", "and")
      return Expr(:&&, map(read, sexp[2:end], meta[2:end])...)
    end

    ## or/|| (julia makes these special forms too.)
    if sexp[1] in ("||", "or")
      return Expr(:||, map(read, sexp[2:end], meta[2:end])...)
    end

    # typing assert form
    if sexp[1] == "::"
      return Expr(:(::), map(read, sexp[2:end], meta[2:end])...)
    end

    # parameterized typing form
    if sexp[1] == "curly"
      return Expr(:curly, map(readsym, sexp[2:end], meta[2:end])...)
    end

    # dot call form -
    if sexp[1][1] == '.'
      # first, if it's like (.x y), this is y.x()
      if length(sexp[1]) > 1
        return Expr(:call, Expr(:., read(sexp[2], meta[2]),
                                QuoteNode(readsym(sexp[1][2:end], meta[1]))),
                    map(read, sexp[3:end], meta[3:end])...)
        # second, if it's (. x y z a b...) this is x.y.z.a.b. ...
      else
        e = readsym(sexp[end], meta[end])
        for sym in reverse(collect(zip(sexp[2:end-1], meta[2:end-1])))
          e = Expr(:., readsym(sym...), QuoteNode(e))
        end
        return e
      end
    end

    # if none of these things, it's just a regular function call.
    # in julia syntax, this is
    return Expr(:call,
                read(sexp[1], meta[1]),
                map(read, sexp[2:end], meta[2:end])...)
  else
    # Atoms

    if sexp == "nil"
      return nothing
    elseif sexp == "true"
      return true
    elseif sexp == "false"
      return false
    elseif isdigit(sexp[1]) ||
        (sexp[1] == '-' && length(sexp) > 1 && isdigit(sexp[2]))
      return readnumber(sexp, meta)
    elseif sexp[1] == '"'
      # strip the '"' characters at both ends first.
      return unescape_string(sexp[2:end-1])
    elseif sexp[1] == '\\' && length(sexp) > 1
      return readchar(sexp, meta)
    elseif sexp[1] == ':'
      # :[symbol]* -> keyword (symbol in julia, like :(:symbol))
      if contains(sexp, ".") || contains(sexp, "/")
        throw(InvalidTokenError(meta...,sexp))
      end
      return Expr(:quote,symbol(escapesym(sexp[2:end])))
    else
      # [symbol]* -> symbol (variable in julia, like :symbol)
      # the base option is that we're dealing with a symbol.
      return readsym(sexp, meta)
    end
  end
end

function readfunc(sexp, meta)
  # automatically assumes first form is called 'fn',
  # this makes it work for fn/defn at the same time.
  # presumably you would check sexp[1] == "fn" before dispatching to this
  # function.

  # TODO need more error checking here - make sure types of the name/docstring
  # match. It's being implicitly done by the other read functions, but
  # prechecking will allow for a better error message than "Invalid Token"
  # which can be cryptic if you don't know what's going on.
  if isa(sexp[2], Array) && sexp[2][1] == VECID
    # (fn [x] body)
    # small optimization. If it's an anonymous function with only one
    # term in the body, replace with -> syntax.
    if length(sexp) <= 3
      return Expr(:->,
                  Expr(:tuple,
                       #2:end avoids the VECID element.
                       map(readsym, sexp[2][2:end], meta[2][2:end])...),
                  if length(sexp) == 2; :nothing else read(sexp[3], meta[3]) end)
    else
      return Expr(:function,
                  Expr(:tuple, map(readsym, sexp[2][2:end], meta[2][2:end])...),
                  Expr(:block, map(read, sexp[3:end], meta[3:end])...))
    end
  elseif isa(sexp[3], Array) && sexp[3][1] == VECID
    # (fn name [x] body)
    return Expr(:function,
                Expr(:call,
                     readsym(sexp[2], meta[2]),
                     map(readsym, sexp[3][2:end], meta[3][2:end])...),
                Expr(:block, map(read, sexp[4:end], meta[4:end])...))
  elseif isa(sexp[4], Array) && sexp[4][1] == VECID
    # as of now, docstrings are ignored
    # in reality, we'd want to emit 2 forms here, one for the docstring,
    # and one for the function. There's no way to do that without the
    # begin/end cruft appearing as well.

    # TODO add support for Expr(:toplevel) which can hold multiple forms
    # to be printed out sequentially (without breaks) in the main document.
    # the hard part is going to be being able to read that stuff back into
    # clojure in cljreader.

    # (fn name "docstring" [x] body)
    return Expr(:function,
                Expr(:call,
                     readsym(sexp[2], meta[2]),
                     map(readsym, sexp[4][2:end], meta[4][2:end])...),
                Expr(:block, map(read, sexp[5:end], meta[5:end])...))

  else
    throw(InvalidFormStructureError(
            meta[1]..., sexp[1], sexp,
            string(
              "no function body found in position 2-4",
              "function definition must match one of the following forms: ",
              "(fn [x] ...), (fn name [x] ...), (fn name \"docstring\" [x] ...)"
              )))
  end
end

"""
Special symbols: clojure allows more than julia is capable of handling.
eg: \*?!+-':><_ (: has to be non-repeating.)
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
* + -> \^+ ⁺
* - -> \^- ⁻(superscript -, basically)
* ' -> \prime ′ (Who uses a quote in the name of a variable?)
* < -> \angle ∠
* > -> \whitepointerright ▻ (hard to find a > looking unicode character.)
* : -> \textbrokenbar ¦

Alternatively, you could convert it to a messy escaped ASCII version, if
desired.

* ! is given
* _ -> __ (needs to be escaped)
* * -> \_s
* ? -> \_q
* + -> \_p
* - -> \_d
* ' -> \_a
* > -> \_g
* < -> \_l

This might be nice for situations where you're going to only macroexpand,
since it avoids unicode headaches. It would suck if you actually had to
go read the Julia code afterwards though. ASCII only mode is only useful if
you need ASCII compatability for some external reason.
"""
function escapesym(form, unicode=true)
  str = form
  if unicode
    str = replace(str, "*", "°")
    str = replace(str, "?", "ʔ")
    str = replace(str, "+", "⁺")
    str = replace(str, "-", "¯")
    str = replace(str, "'", "′")
    str = replace(str, "<", "∠")
    str = replace(str, ">", "▻")
    str = replace(str, ":", "¦")
  else
    str = replace(str, "_" ,"__")
    str = replace(str, "*" ,"_s")
    str = replace(str, "?" ,"_q")
    str = replace(str, "+" ,"_p")
    str = replace(str, "-" ,"_d")
    str = replace(str, "'" ,"_a")
    str = replace(str, "<", "_l")
    str = replace(str, ">", "_g")
    str = replace(str, ":", "_c")
  end
  return str
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

Of course, adding sanitizing means we have to also know when we're dealing with
operators and make sure to exclude them from the sanitization process.
"""
function readsym(form, meta, unicode=true)
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
  if length(form) < 4 && match(Regex(validops), form) != nothing
    return symbol(form)
  end

  b = readbuiltin(form)
  if b != nothing return b end

  # symbol must begin with a -,_,or a-zA-Z character.
  # @ is also allowed for macros.
  if match(r"^[@-_a-zA-Z]", form) == nothing
    throw(InvalidTokenError(meta...,form))
  end

  # extract type
  symtype = split(form, "::")
  # Note that this is strict parsing.
  # We could just ignore everything after the second :: and beyond in the
  # symbol
  if length(symtype) > 2
    throw(InvalidTokenError(meta...,str))
  end

  s = symtype[1]
  if length(symtype) > 1
    t = symtype[2]
  end

  # now parse s for dots and slashes
  # the dotted name is built in reverse.
  parts = split(s, r"[./]")
  e = symbol(escapesym(parts[1]))
  for p in parts[2:end]
    e = Expr(:., e, QuoteNode(symbol(escapesym(p))))
  end

  if length(symtype) > 1
    return Expr(:(::), e, readsym(t, meta))
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

  # TODO at minimum implement all operators.
  return nothing
end


function readchar(str, meta)
  if str == "\\newline"
    return '\n'
  elseif str == "\\space"
    return ' '
  elseif str == "\\tab"
    return '\t'
  elseif str == "\\formfeed"
    return '\f'
  elseif str == "\\backspace"
    return '\b'
  elseif str == "\\return"
    return '\r'
  else
    # str[2] to get the character after the \
    return str[2]
  end
end

function readint(str, meta, radix=10)
  # cascade along integer sizes to larger and larger types.
  try
    parse(Int, str, radix)
  catch OverflowError
    try
      parse(Int64, str, radix)
    catch OverflowError
      try
        parse(Int128, str, radix)
      catch OverflowError
        parse(BigInt, str, radix)
      end
    end
  end
end

function readnumber(str, meta)
  # if it's just [0-9]* it's an integer
  if ismatch(r"^-?[0-9]+$", str)
    readint(str, meta)
  elseif ismatch(r"^[0-5]?[0-9]+r-?[0-9]+$", str)
    p = split(str,'r')
    try
      # it's possible to still have a malformatted number
      # this is an int with a specified radix.
      readint(p[2], meta, readint(p[1], meta))
    catch a
      if isa(a, ArgumentError)
       throw(WrappedException(meta..., a, "could not parse number."))
      else
        rethrow(a)
      end
    end
  elseif ismatch(r"^-?[0-9]+(\.[0-9]+)?([fe]-?[0-9]+)?$", str)
    try
      # it's possible to still have a malformatted number
      parse(Float64, str)
    catch a
      if isa(a, ArgumentError)
        throw(WrappedException(meta...,a))
      else
        rethrow(a)
      end
    end
  elseif ismatch(r"^-?([0-9]+)/([0-9]+)", str)
    try
      p = split(str, '/')
      //(readint(p[1], meta), readint(p[2], meta))
    catch a
      if isa(a, ArgumentError)
        throw(WrappedException(meta...,a))
      else
        rethrow(a)
      end
    end
  else
    throw(InvalidTokenError(meta...,str))
  end
end

end #module


