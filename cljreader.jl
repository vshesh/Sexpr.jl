"""
File: cljreader.jl
Author: Vishesh Gupta

contains functions that are intended to take a julia expression object and
output an s-expression that is valid in clojure.

Also contains functions to format and print the s-expression, based on what I
feel are sensible indentation rules.

"""
module CLJReader


"""
tosexp takes a julia expression and outputs it as a tuple s-expression form.
this makes it much easier to write a reader for.
"""
function tosexp(ex::Expr)
  (ex.head, map(tosexp, ex.args)...)
end
function tosexp(ex)
  ex
end

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
function read(sexp::Tuple)
  # empty list
  # :block -> do
  # :if -> if
  # :let -> let
  # :function -> fn (or defn? This is a problem.)
  # :-> -> fn
  # := -> def

  # Macro special forms
  # :quote -> `() (quote is *actually* syntax-quote)
  # esc -> ~'? resolves the symbol without gensymming.

  # :. -> (.b a) (dot-call syntax)
  # :(::) -> (:: ) (type definition syntax)


  # :vect -> [] (vector literal)
  # (:call, :Dict...) -> {} (dict literal)

  # :macrocall -> (@macro ) (macro application)
  # :call -> (f a b) (function call)

  # Special Atoms
  # :// -> rational const.
  #
end

end
