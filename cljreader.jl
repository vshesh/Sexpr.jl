"""
File: cljreader.jl
Author: Vishesh Gupta

contains functions that are intended to take a julia expression object and
output an s-expression that is valid in clojure.

Also contains functions to format and print the s-expression, based on what I
feel are sensible indentation rules.

"""
module CLJReader

export read
read(s::Any) = string(s)
read(s::Void) = "nil"
read(s::Bool) = string(s)
read(s::Symbol) = string(s)
read(s::AbstractString) = string("\"", escape_string(s), "\"")

read(n::Union{Int, Int8, Int16, Int32, Int64, Int128, BigInt}) = string(n)
read(n::Union{UInt, UInt8, UInt16, UInt32, UInt64, UInt128}) = string("0x",base(16,n))
read(n::Union{Float16, Float32, Float64, BigFloat}) = string(n)
read(n::Union{Rational, Complex}) = string(n)
# TODO - keywords!?
# They are Expr(:quote, Symbol)s, but it's impossible then to tell a quoted var
# from a keyword.

"""
Expression heads that are not being handled here:
* :comparison - this requires an infix grammar of understanding how to convert
  the entire list of comparison tokens to an s-expression.
  When going from clojure to julia, everything is done as a function call, so to
  go the other way it shouldn't be necessary to deal with this.
  * special, very common cases may be allowed (i.e, x </>/>=/<= y types) to
    support reading raw julia files (that weren't first translated from
    s-expression syntax). This is NOT a priority though.
"""
function read(sexp::Union{Array,Tuple}, toplevel=false)
  # empty list
  if sexp[1] == :tuple && length(sexp) == 1
    return ()
  end
  # :block -> do
  if sexp[1] == :block
    if length(sexp) == 2
      return read(sexp[2])
    else
      return ("do", map(read, sexp[2:end])...)
    end
  end
  # :if -> if
  if sexp[1] == :if
    return ("if", map(read, sexp[2:end])...)
  end
  # :let -> let
  if sexp[1] == :let
    # pass
  end
  # :function -> fn (or defn? This is a problem.)
  # :-> -> fn
  if sexp[1] == :->
    # if the next element is a single symbol, wrap it in a tuple.
    args = sexp[2]
    if isa(args, Symbol)
      args = (VECID, args)
    else
      args[1] = VECID
    end
    return ("fn", args, read(sexp[3]))
  end
  # := -> def
  # you should only have def at the toplevel. no defing vars inside something.
  if sexp[1] == :(=) && toplevel
    return ("def", map(read, sexp[2:end])...)
  end


  # Macro special forms
  # :quote -> `() (quote is *actually* syntax-quote)
  # esc -> ~'? resolves the symbol without gensymming.

  # :. -> (.b a) (dot-access syntax)
  # :(::) -> (:: ) (type definition syntax)


  # :vect -> [] (vector literal)
  if sexp[1] == :vect
    return (:vect, map(read, sexp[2:end])...)
  end

  # (:call, :Dict...) -> {} (dict literal)


  # :macrocall -> (@macro ) (macro application)
  # :call>:. -> (.b a) (dot-call syntax)
  # :call -> (f a b) (function call)

  # Special Atoms
  # :// -> rational const.
  #
end

end
