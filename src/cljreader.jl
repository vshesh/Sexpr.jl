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

include("util.jl")
using .Util: mapcat, isform, unescapesym, VECID, DICTID


read(s, t::Bool=false) = string(s)
read(s::Void, t::Bool=false) = "nil"
#read(s::Bool) = string(s)

#= Numbers =#
#read(n::Union{Int, Int8, Int16, Int32, Int64, Int128, BigInt}) = string(n)
#read(n::Union{Float16, Float32, Float64, BigFloat}) = string(n)
read(n::Union{UInt, UInt8, UInt16, UInt32, UInt64, UInt128}, t::Bool=false) =
  string("0x",base(16,n))
read(r::Rational, t::Bool=false) = string(read(r.num, t), "/", read(r.den, t))

#= Characters, doesn't handle unicode and such. =#
function read(c::Char, t::Bool=false)
  if c == '\n'
    return "\\newline"
  elseif c == ' '
    return "\\space"
  elseif c == '\t'
    return "\\tab"
  elseif c == '\f'
    return "\\formfeed"
  elseif c == '\b'
    return "\\backspace"
  elseif c == '\r'
    return "\\return"
  else
    return string("\\",c)
  end
end
#= Strings =#
read(s::AbstractString, t::Bool=false) = string("\"", escape_string(s), "\"")
#= keywords =#
read(k::QuoteNode, t::Bool=false) = k.value == :nothing ? ":nothing" : string(":", read(k.value))
#= symbols =#
read(s::Symbol, t::Bool=false) = s == :nothing ? "nil" : unescapesym(string(s))

"""
Use Util.tosexp in src/util.jl which will take an expression
and convert it into a array style sexp which is a representation of how
julia's internal parser sees things. This sexp is parsed

Expression heads that are not being handled here:
* :comparison - this requires an infix grammar of understanding how to convert
  the entire list of comparison tokens to an s-expression.
  When going from clojure to julia, everything is done as a function call, so to
  go the other way it shouldn't be necessary to deal with this.
  * special, very common cases may be allowed (i.e, x </>/>=/<= y types) to
    support reading raw julia files (that weren't first translated from
    s-expression syntax). This is NOT a priority though.
"""
function read(sexp::Array, toplevel::Bool=false)
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

  if sexp[1] == :comparison
    if length(sexp) == 4
      return (read(sexp[3]), read(sexp[2]), read(sexp[4]))
    end
  end

  # :let -> let
  if sexp[1] == :let
    # pass
  end

  # :function -> fn (or defn? This is a problem.)
  if sexp[1] == :function
    # pass
  end
  
  # :-> -> fn
  if sexp[1] == :->
    # if the next element is a single symbol, wrap it in a tuple.
    args = sexp[2]
    if isa(args, Symbol)
      args = (VECID, args)
    else
      args[1] = VECID
    end
    return ("fn",
            isa(args, Symbol) ? (:vect, read(args)) : (:vect, map(read, args[2:end])...),
            read(sexp[3]))
  end
  # := -> def
  # you should only have def at the toplevel. no defing vars inside something.
  if sexp[1] == :(=) && toplevel
    return ("def", map(read, sexp[2:end])...)
  end


  # Macro special forms
  # :macro -> macro definitions should be ignored for now
  if sexp[1] == :macro
    return ("defmacro",)
  end
  # :quote -> `() (quote is *actually* syntax-quote)
  # esc -> ~'? resolves the symbol without gensymming.
  # :$>:tuple>:... unquote splice ~@
  # :$ unquote ~

  # Julia Special Forms
  # :. -> (.b a) (dot-access syntax)
  if sexp[1] == :.
    # heads up that sexp[3] should always be a quotenode.
    # TODO one more optimization is that if it looks like
    # (. (. (form) quotenode) quotenode)
    # it can be made into (. (form) quotenode.quotenode) instead.
    if isa(sexp[2], Symbol) && isa(sexp[3], QuoteNode)
      return string(read(sexp[2]), ".", read(sexp[3].value))
    elseif isform(sexp[2]) && isa(sexp[3], QuoteNode)
      s = read(sexp[2])
      if isa(s, AbstractString)
        return string(s, '.', read(sexp[3].value))
      elseif length(sexp[2]) >= 3 && isa(sexp[2][3], QuoteNode)
        return (s[1:end-1]..., string(s[end], '.', read(sexp[3].value)))
      else
        return (".", s, read(sexp[3].value))
      end
    end
  end
  # :(::) -> (:: ) (type definition syntax)
  if sexp[1] == :(::)
    # again, sexp[3] should be a symbol.
    # if it looks like (:: symbol symbol)
    # then we need to do the conversion here directly.
    if all(x->isa(x, Symbol), sexp[2:end])
      return join(sexp[2:end], "::")
    elseif isform(sexp[2]) && isa(sexp[3], Symbol)
      s = read(sexp[2])
      if isa(s,AbstractString)
        return string(s, "::", read(sexp[3]))
      end
    end
    return ("::", map(read, sexp[2:end])...)
  end
  # parameterized types.
  if sexp[1] == :curly
    return ("curly", map(read, sexp[2:end])...)
  end
  if sexp[1] == :&&
    return ("and", map(read, sexp[2:end])...)
  end
  if sexp[1] == :||
    return ("or", map(read, sexp[2:end])...)
  end

  # Special Atoms
  # :// -> rational const.
  if sexp[1] == :call && sexp[2] == ://
    return string(read(sexp[3], toplevel), "/", read(sexp[4], toplevel))
  end
  
  # Literals
  # :vect -> [] (vector literal)
  if sexp[1] == :vect
    return (:vect, map(read, sexp[2:end])...)
  end
  # (:call, :Dict...) -> {} (dict literal)
  if sexp[1] == :call && sexp[2] == :Dict
    return (:dict, map(read,mapcat(x->x[2:end], sexp[3:end]))...)
  end


  # :call>:. -> (.b a) (dot-call syntax)
  if sexp[1] == :call && isform(sexp[2]) && sexp[2][1] == :.
    return (read(sexp[2]), map(read, sexp[3:end])...)
  end
  
  # :macrocall -> (@macro ) (macro application)
  # have to write readquoted to make this work.
  # it shouldn't be too hard - just atoms and literals need to be read out.
  if sexp[1] == :macrocall
    return (read(sexp[2]), map(readquoted, sexp[3:end])...)
  end
  
  # :call -> (f a b) (function call)
  if sexp[1] == :call
    return (map(read, sexp[2:end])...)
  end

end

function readquoted(sexp)
  if isform(sexp)
    # TODO move the reading of VECID/DICTID type deals to a readliteral
    # function which is called from read if the first element of the form
    # is not a string.
    if sexp[1] == :vect
      (:vect, map(readquoted, sexp[2:end])...)
    elseif sexp[1] == :call && sexp[2] == :Dict
      (:dict, map(readquoted, mapcat(x->x[2:end], sexp[3:end]))...)
    elseif sexp[1] == :tuple
      (map(readquoted, sexp[2:end])...)
    else
      map(readquoted, sexp)
    end
  else
    # strip the \blockfull character from all RESERVED_WORDS
    if isa(sexp, Symbol)
      s = string(sexp)
      if startswith(s, '█') &&
         # blockfull character apparently takes up 3 characters
         convert(ASCIIString, s[4:end]) in Util.RESERVED_WORDS
        convert(ASCIIString, s[4:end])
      end
    else
      read(sexp)
    end
  end
end

end
