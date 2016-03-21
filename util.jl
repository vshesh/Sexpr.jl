module Util


export mapcat

export VECID, DICTID
export stripmeta, tosexp, isform

# ------------------------- General Utilities -----------------------

mapcat(f, args::Array...) = vcat(map(f, args...)...)



# --------------------------- Project Specific Utilities --------------

VECID = :vect
DICTID = :dict

"""
Strips meta nodes - so far this seems to only be LineNumberNodes, but
there are a few more types of nodes that might also apply
Expr, QuoteNode, SymbolNode, LineNumberNode, LabelNode, GotoNode, TopNode

Are the main kinds of nodes. 
"""
stripmeta(expr::Expr) = Expr(expr.head, stripmeta(expr.args)...)
stripmeta(expr::Array) = map(stripmeta,
  filter(x -> !isa(x, LineNumberNode), expr))
stripmeta(expr) = return expr


"""
tosexp takes a julia expression and outputs it as a tuple s-expression form.
this makes it much easier to write a reader for.
"""
tosexp(ex::Expr) = Any[ex.head, map(tosexp, ex.args)...]
tosexp(ex::QuoteNode) = tosexp(ex.value)
tosexp(ex) = ex

isform(sexp) = isa(sexp, Tuple) || isa(sexp, Array)

delevel(ex::Array{Expr}) = mapcat(delevel, ex)
function delevel(ex::Expr)
  if ex.head == :toplevel
    ex.args
  else
    [ex]
  end
end


function expand(ex::Expr)
  if ex.head == :module
    Expr(:module, ex.args[1], ex.args[2], macroexpand(ex.args[3]))
  else
    macroexpand(ex)
  end
end


end

