module Util


export mapcat

export VECID, DICTID
export stripmeta, tosexp, isform

# ------------------------- General Utilities -----------------------

"""
concatenates results of mapping f to args.
f should return an array.
"""
mapcat(f, args...) = vcat(map(f, args...)...)


"""
Finds all files in a directory recursively and gives dir path + remaining path.
"""
function finddir(dir::AbstractString)
  for path in readdir(dir)
    fullpath = joinpath(dir, path)
    if isfile(fullpath)
      produce(fullpath)
    elseif isdir(fullpath)
      finddir(fullpath)
    end
  end
end


# --------------------------- Project Specific Utilities --------------

VECID = :vect
DICTID = :dict


oneline(x::AbstractString) = x
function oneline(sexp::Union{Array, Tuple})
  if length(sexp) == 0
    "()"
  elseif sexp[1] == VECID
    "[$(join(map(oneline, sexp[2:end]), " "))]"
  elseif sexp[1] == DICTID
    "{$(join(map(oneline, sexp[2:end]), " "))}"
  else
    "($(join(map(oneline, sexp), " ")))"
  end
end

"""
Strips meta nodes - so far this seems to only be LineNumberNodes, but
there are a few more types of nodes that might also apply
Expr, QuoteNode, SymbolNode, LineNumberNode, LabelNode, GotoNode, TopNode

Are the main kinds of nodes.
"""
stripmeta(expr::Expr) = Expr(expr.head, stripmeta(expr.args)...)
stripmeta(expr::Array) = map(stripmeta,
  filter(x -> !isa(x, LineNumberNode), expr))
stripmeta(expr) = expr

"""
determine if we're dealing with a form.
For various reader contexts. It's a lot less characters to type isform(sexp)
then the longer expression on the right, and it allows a consistent place
to define the idea of a form.
"""
isform(sexp) = isa(sexp, Tuple) || isa(sexp, Array)


"""
tosexp takes a julia expression and outputs it as a tuple s-expression form.
this makes it much easier to write a reader for.
"""
tosexp(ex::Expr) = Any[ex.head, map(tosexp, ex.args)...]
#tosexp(ex::QuoteNode) = Any[:quote, tosexp(ex.value)]
# Having quotenodes makes it easy to determine what is a keyword and
# what is a quoted expression.
# this does make it harder to use Util.tosexp as a debugging tool, so maybe
# TODO it would be good to write debug function like alltosexp that makes all
# expr-family objects into a sexpr, in which case you'd see [:quote, :x] there.
tosexp(ex) = ex

"""
delevel takes any Expr(:toplevel, ...) and expands it out, giving you an array.
made to be called in Transpile.transpiler, it's the last step of the processing
pipeline (so far).
"""
delevel(ex::Array) = mapcat(delevel, ex)
function delevel(ex::Expr)
  if ex.head == :toplevel
    ex.args
  else
    [ex]
  end
end
delevel(ex) = ex


"""
Macroexpand a module in the context of the module itself, rather than
in global scope. Will also evaluate macros in the module itself, so if a
macro is defined _before_ it is used, it will be available to subsequent
expressions.
"""
function expand_module(ex::Expr)
  @assert ex.head === :module
  std_imports = ex.args[1]::Bool
  name = ex.args[2]::Symbol
  body = ex.args[3]::Expr
  mod = Module(name, std_imports)
  newbody = quote end
  modex = Expr(:module, std_imports, name, newbody)
  for subex in body.args
    expandf = ()->macroexpand(subex)
    subex = eval(mod, :($expandf()))
    push!(newbody.args, subex)
    eval(mod, subex)
  end
  modex, mod
end

# printing macros still a pain in the butt.
# import Base.string
#
# function string(ex::Expr)
#   if ex.head == :macro
#     ex.head = :function
#     s = string(ex)
#     ex.head = :macro
#     Base.string("macro", s[9:end])
#   elseif ex.head == :quote
#     Base.string(":(", map(tostring, ex.args)..., ")")
#   elseif ex.head == :$
#     Base.string("\$(", map(tostring, ex.args)..., ")")
#   else
#     Base.string(ex)
#   end
# end

end
