module Util

export stripmeta, tosexp, VECID, DICTID

VECID = :vect
DICTID = :dict


stripmeta(expr::Expr) = Expr(expr.head, stripmeta(expr.args)...)
stripmeta(expr::Array) = map(stripmeta, filter(x -> !isa(x, LineNumberNode), expr))
stripmeta(expr) = return expr


"""
tosexp takes a julia expression and outputs it as a tuple s-expression form.
this makes it much easier to write a reader for.
"""
tosexp(ex::Expr) = Any[ex.head, map(tosexp, ex.args)...]
tosexp(ex::QuoteNode) = tosexp(ex.value)
tosexp(ex) = ex


isform(sexp) == isa(sexp, Tuple) || isa(sexp, Array)


end

