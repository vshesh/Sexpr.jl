<style>
pre.sourceCode {
  padding: 5px;
}
code.sourceCode {
  font-family: Inconsolata;
  font-size: 15;
}
</style>

# Julia and Sexp.jl syntax side by side {style="text-align:center;"}

<div style="display:flex; margin:0 auto; width: 60%; justify-content:space-around;">
<div style="flex:1; padding-left:10%;">

```clojure
; nil, true, and false work as expected.
nil
true
false

; numbers - can be int or float
; ints
1
; 16r means base 16
16r1ef1346bafdc
; can be any size, will use smallest fitting type for the int.
1239813049871209874102349710234978120394871203948710239487102394871029347

```

</div>
<div style="flex:1; padding-left:10%;">

```julia
# nothing, true and false in julia.
nothing
true
false

# numbers
# int
1

```

</div>
</div>
