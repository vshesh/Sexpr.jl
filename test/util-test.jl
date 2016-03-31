module UtilTest

using FactCheck

include("../src/util.jl")
importall .Util


facts("(un)escapesym tests") do
  @fact Util.escapesym("x*+*?><':-_-'", false) --> "x_s_p_s_q_g_l_a_c_d___d_a"
  @fact Util.unescapesym("x_s_p_s_q_g_l_a_c_d___d_a", false) --> "x*+*?><':-_-'"
end

facts("isform tests") do
  @fact Util.isform(["x"]) --> true
  @fact Util.isform("x") --> false
  @fact Util.isform(:x) --> false
  @fact Util.isform(:(1 + 1)) --> false
end

end
