module Reader

export VECID, DICTID
export parsesexp, extractsexp
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
    push!(sexp[end], word)
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


function extractsexp(sexp::Dict{Symbol,Any})
  expr = sexp[:sexp]
  if isa(expr, Array{Any})
    map(extractsexp, expr)
  else
    expr
  end
end

""" only works if length(xs) % n == 0"""
partition(n,x) = [{x[i:min(i+n-1,length(x))]} for i in 1:n:length(x)]
"""

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
        # note that (:__dict__, pair of operations) will always be an
        # odd number of forms
        throw(InvalidFormCountError(0,0,"map",sexp,
                                    "even number of forms",
                                    "$(length(sexp))"))
      end
      return Expr(:call, :Dict, )
    end
    # vector
    if sexp[1] == VECID
      return Expr(:vect, map(read, sexp[2:end])...)
    end

    # if none of these things, it's just a regular function call.
    # in julia syntax, this is
    return Expr(:call, symbol(sexp[1]), map(read, sexp[2:end])...)
  else
    # Special reader macros
    # ' (quote)


    # Atoms

    # nil -> nothing
    # true -> true
    # false -> false
    # [0-9].* -> some kind of number
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
      #this should just strip the '"' characters at both ends
      return sexp[2:end-1]

    else
      # this is an unrecognized literal, error
      throw(InvalidTokenError(0,0,sexp))
    end

    # if it starts with a digit, it MUST be a number, or it's an error
  end
end

function readnumber(str)
  # if it's just [0-9]* it's an integer
  if ismatch(r"^-?[0-9]+$", str)
    parse(Int, str)
  elseif ismatch(r"^-?[0-9]+r[0-9]+$", str)
    p = split(str,'r')
    try
      # it's possible to still have a malformatted number
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
    throw(InvalidTokenError())
  end
end

end















