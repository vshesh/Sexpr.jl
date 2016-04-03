module HarnessTest

using FactCheck
include("../src/harness.jl")

facts("option parsing tests") do
  @fact Harness.getopts(["-i"])[:invert] --> true
  @fact Harness.getopts(["-c"])[:cat] --> true
  @fact Harness.getopts(["-e", "clj"])[:extension] --> Any[Any["clj"]]
  @fact Harness.getopts(["-e", "clj", "-e", "cljs"])[:extension] --> Any[Any["clj"], Any["cljs"]]
  @fact Harness.getopts(["-l", "3"])[:lines] --> 3
  @fact Harness.getopts(["-o", "dir"])[:output] --> Any["dir"]
  @fact Harness.getopts(["dir"])[:files] --> Any["dir"]
end

facts("isset tests") do
  @fact Harness.isset(Dict(:x=>1), :x) --> true
  @fact Harness.isset(Dict(:x=>true), :x) --> true
  @fact Harness.isset(Dict(:x=>false), :x) --> false
  @fact Harness.isset(Dict(:x=>[]), :x) --> false
  @fact Harness.isset(Dict(:x=>[1]), :x) --> true
  @fact Harness.isset(Dict(:x=>true), :y) --> false
end

end
