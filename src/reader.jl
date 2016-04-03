module Reader

include("errors.jl")
using .Errors

include("parser.jl")
using .Parser: DICTID, VECID

include("util.jl")
using .Util: isform, escapesym

export read


""" only works if length(xs) % n == 0"""
partition(n,x) = [x[i:min(i+n-1,length(x))] for i in 1:n:length(x)]


"""
takes an s-expression and a meta information block about said s-expression
and uses it to read the form into a julia form.
The sexp should be passed as an Array of either strings or arrays of strings
(eg, a tree of strings). So far, meta information only includes the line/col
number of each atom as it's read in, which is used for error reporting.

There are some comprehensive tests in tests/testfiles/02-specialforms.clj that
show what is allowed in the readform system and what is not.
"""
read(sexp, meta) = isform(sexp) ? readform(sexp, meta) : readatom(sexp, meta)

function readform(sexp, meta)
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
        return Expr(:tuple, map(readquoted, sexp[2], meta[2])...)
      else
        return readquoted(sexp[2], meta[2])
      end
    
    # it does not make sense to encounter ~ or ~@ outside of a quoted form.
    # in this case, the correct thing to do is to throw and error
    elseif sexp[1] == "~" || sexp[1] == "~@"
      throw(InvalidFormStructureError(meta[1]..., sexp[1], sexp,
            "unquote expression found outside of quote expression."))
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
  # the last form needs to be wrapped in a call to Sexpr.read.
  if sexp[1] == "defmacro"
    e = readfunc(sexp, meta)
    e.head = :macro
    # this should wrap the entire block
    e.args[end].args[end] = Expr(:call, :(Sexpr.rehydrate), e.args[end].args[end])
    return e
  end

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
  
  # module related
  # module
  # import
  # export
  # using
  # include is a function, so it's fine
  
  
  # # "get" operator (:ref in julia)
  # if sexp[1] == "aget"
  #   # surprisingly, a[] == a[1] in julia, which I consider strange.
  #   return Expr(:ref, map(read, sexp[2:end], meta[2:end])...)
  # end
  # # : colon operator, for the purpose of slices and ranges
  # if sexp[1] == ":"
  #   if length(sexp) < 3
  #     throw(InvalidFormCountError(meta[1]..., ":", sexp,
  #                                 "at least 3 forms", "$(length(sexp))"))
  #   end
  #   return Expr(:(:), map(read, sexp[2:end], meta[2:end])...)
  # end
  
  
  # for
  # try/catch
  # deftype -> type

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
    # TODO :: error checking - only contains symbol or curly form with symbols.
    for form in sexp[3:end]
      if isform(sexp) && sexp[1] != "curly"
      end
    end
    if length(sexp) == 3
      return Expr(:(::), read(sexp[2], meta[2]), read(sexp[3], meta[3]))
    else
      return Expr(:(::),
                  read(sexp[2], meta[2]),
                  Expr(:curly, :Union, map(read, sexp[3:end], meta[3:end])...))
    end
  end

  # parameterized typing form
  if sexp[1] == "curly"
    for i in 2:length(sexp)
      if isform(sexp[i]) && sexp[i][1] != "curly"
        throw(InvalidFormStructureError(meta[i][1]..., "curly", sexp,
          string("curly forms can only have other curly forms as subexpressions.",
                 "Found a $(sexp[i][1]) form at position $i instead.")))
      end
    end
    
    # have to map read because there can be numbers too, eg:
    # Array{Any,1}. => (curly Array Any 1)
    # Or further curly forms like
    # Union{Array{Int}, Array{Int64}} =>
    # (curly Union (curly Array Int) (curly Array Int64))
    return Expr(:curly, map(read, sexp[2:end], meta[2:end])...)
  end

  # dot call form -
  if sexp[1][1] == '.'
    if length(sexp[1]) > 1
      # first, if it's like (.x y), this is y.x()
      return Expr(:call, Expr(:., read(sexp[2], meta[2]),
                              QuoteNode(readsym(sexp[1][2:end], meta[1]))),
                  map(read, sexp[3:end], meta[3:end])...)
    else
      # second, if it's (. x y z a b...) this is x.y.z.a.b. ...
      e = read(sexp[2], meta[2])
      for i in 3:(length(sexp))
        nextnode = readsym(sexp[i], meta[i])
        e = Expr(:., e,
                 isa(nextnode, Expr) && nextnode.head == :. ?
                 nextnode : QuoteNode(nextnode))
      end
      return e
    end
  end
  
  #macro call form
  if sexp[1][1] == '@'
    # for a macro call, we want to read all the atoms rather than
    # read all the forms.
    return Expr(:macrocall, readsym(sexp[1], meta[1]),
                map(readquoted, sexp[2:end], meta[2:end])...)
  end
  
  # if none of these things, it's just a regular function call.
  # in julia syntax, this is
  return Expr(:call,
              read(sexp[1], meta[1]),
              map(read, sexp[2:end], meta[2:end])...)
end

"""
readquoted does the same thing as read but quotes the whole thing, for
macrocall purposes.

eg: read(["if", "true", "1", "0"]) -> :(true ? 1 : 0)
    readquoted(["if", "true", "1", "0"]) -> [:if, true, 1, 0]

In some sense, this is just a subset of read with the special forms removed,
and only literals and atoms included. However, the difference here is
that the readquoted function never calls read, so that none of the special
forms are evaluated. It's a subtle difference in the way the recursion tree
is handled, but what seems like repetition of code is unforunately necessary.
"""
function readquoted(sexp, meta)
  if isform(sexp)
    # handle unquoting too!
    if sexp[1] == "~"
      # we need to read rather than readquoted the form next to this one
      Expr(:call, :eval, read(sexp[2], meta[2]))
    elseif sexp[1] == "~@"
      Expr(:..., Expr(:call, :eval, read(sexp[2], meta[2])))
    elseif sexp[1] == VECID
      Expr(:vect, [readquoted(sexp[i], meta[i]) for i in 2:length(sexp)]...)
    elseif sexp[1] == DICTID
      # MUST have pairs of operations
      if length(sexp) % 2 != 1
        # note that (DICTID, pair of operations) will always be an
        # odd number of forms
        throw(InvalidFormCountError(meta[1]...,"map",sexp,
                                    "even number of forms",
                                    "$(length(sexp))"))
      else
        Expr(:call, :Dict,
              map(x -> Expr(:(=>), x...),
                  partition(2, map(readquoted,sexp[2:end], meta[2:end])))...)
      end
    else
      Expr(:tuple, map(readquoted, sexp, meta)...)
    end
  else
    let a = readatom(sexp, meta)
      if isa(a, Symbol)
        QuoteNode(a)
      elseif (isa(a, Expr) && a.head == :quote)
        Expr(:quote, a)
      else
        a
      end
    end
  end
end


"""
reads only an atom. Should be passed one stringified atom and one meta object.
Note: do not pass a singleton array. that's not the same thing.
"""
function readatom(sexp::AbstractString, meta)
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

function readfunc(sexp, meta)
  # automatically assumes first form is called 'fn',
  # this makes it work for fn/defn at the same time.
  # presumably you would check sexp[1] == "fn" before dispatching to this
  # function.

  # TODO need more error checking here - make sure types of the name/docstring
  # match. It's being implicitly done by the other read functions, but
  # prechecking will allow for a better error message than "Invalid Token"
  # which can be cryptic if you don't know what's going on.
  if length(sexp) >= 2 && isa(sexp[2], Array) && sexp[2][1] == VECID
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
  elseif length(sexp) >= 3 && isa(sexp[3], Array) && sexp[3][1] == VECID
    # (fn name [x] body)
    return Expr(:function,
                Expr(:call,
                     readsym(sexp[2], meta[2]),
                     map(readsym, sexp[3][2:end], meta[3][2:end])...),
                Expr(:block, map(read, sexp[4:end], meta[4:end])...))
  elseif length(sexp) >= 4 && isa(sexp[4], Array) && sexp[4][1] == VECID
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
  
  # TODO add support for multi arity functions. It's not clear how these should
  # be implemented - separate functions is the way that they're done in julia,
  # but's that not recoverable.
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
                    # others (eg array slice)
                    "|:",
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

  if length(symtype) == 2
    return Expr(:(::), e, readsym(t, meta))
  elseif length(symtype) >= 3
    return Expr(:(::), e, Expr(:curly, :Union, map(x->readsym(x,meta), symtype[2:end])...))
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
  elseif ismatch(r"^[0-5]?[0-9]+r-?[0-9a-z]+$", str)
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
  elseif ismatch(r"^-?[0-9]+(\.[0-9]+)?(e-?[0-9]+)?$", str)
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
    p = split(str, '/')
    //(readint(p[1], meta), readint(p[2], meta))
  else
    throw(InvalidTokenError(meta...,str))
  end
end

end #module
