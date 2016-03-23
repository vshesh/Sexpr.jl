module Transpiler

include("reader.jl")
import .Reader
include("parser.jl")
import .Parser
include("cljreader.jl")
import .CLJReader
include("util.jl")
import .Util

export transpile, lisp_str

transpile(str::AbstractString) = convert(Array{Expr},
  map(x -> Reader.read(x...), zip(Parser.parsesexp(str)...)))

detranspile(ex::Expr) =
  CLJReader.read(Util.stripmeta(Util.tosexp(ex)))

macro clj_str(str::AbstractString)
  transpile(str)
end

macro jl(ex::Expr)
  detranspile(ex)
end

end
