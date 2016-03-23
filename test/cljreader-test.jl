module CLJReaderTest

using FactCheck
include("../src/transpiler.jl")
using .Transpiler


facts("basic form testing") do
  @fact Transpiler.detranspile( :(()) ) --> ()
end

end
