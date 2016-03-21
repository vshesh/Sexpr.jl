module CLJReaderTest
using FactCheck
include("../transpiler.jl")
using .Transpiler


facts("basic form testing") do
  @fact Transpiler.detranspile( :(()) ) --> ()
end

end
