Special forms such as if, do, fn, etc

Julia Specific Special Forms
;; Contains special forms that derive from julia, not clojure
(:: x Int) ||| Any["::", "x", "Int"] ||| :(x::Int)
; there are a lot of issues with expr equality in julia.
(.x symbol) ||| Any[".x", "symbol"] ||| :(symbol.x())


Clojure Special Forms
(if true 1 0) ||| Any["if", "true", "1", "0"] ||| :(true ? 1 : 0)
(if true 1) ||| Any["if", "true", "1"] ||| Expr(:if, true, 1)
(quote x) ||| Any["quote", "x"] ||| Expr(:quote, :x)
(def x 1) ||| Any["def", "x", "1"] ||| :(x = 1)
; function literals ALWAYS have a block in the AST, so we have to Explicitly describe the s-expr.
(fn [x] x) ||| Any["fn", Any["::__vec__::", "x"], "x"] ||| Expr(:->, Expr(:tuple, :x), :x)
(fn f [x] x) ||| Any["fn", "f", Any["::__vec__::", "x"], "x"] ||| :(function f(x) x end)
(let [x 1] x) ||| Any["let", Any["::__vec__::", "x", "1"], "x"] ||| :(let x=1; x end)
(let [x 1 y 2] (+ x y)) ||| Any["let", Any["::__vec__::", "x", "1", "y", "2"], Any["+","x","y"]] ||| :(let x=1,y=2; x+y end)
(do (println "hello") (println "world")) ||| Any["do", Any["println", "\"hello\""], Any["println", "\"world\""]] ||| :(begin println("hello"); println("world") end)
