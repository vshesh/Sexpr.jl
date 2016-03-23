Special forms such as if, do, fn, etc

Lists and Quoted Lists
() ||| Any[] ||| :(())
'() ||| Any["'", Any[]] ||| :(())
; unquoted list should still evaluate to function call.
; also commas shouldn't matter
; TODO should only be able to call symbol or form in the first position.
;      error on other types of constants.
(1,2,3) ||| Any["1", "2", "3"] ||| Expr(:call, 1, 2, 3)
'(+ 2 3) ||| Any["'", Any["+", "2", "3"]] ||| :((+, 2, 3))

Do
(do) ||| Any["do"] ||| :(begin end)
(do (println "hello")) ||| Any["do", Any["println", "\"hello\""]] ||| :(begin println("hello") end)
(do (println "hello") (println "world")) ||| Any["do", Any["println", "\"hello\""], Any["println", "\"world\""]] ||| :(begin println("hello"); println("world") end)

If
; TODO extend reader-test.jl to take ||| e UnclosedError type forms, which allow
; checking of errors thrown at the reader step.
; (if) should throw error
; (if (test)) should throw error
(if true 1) ||| Any["if", "true", "1"] ||| Expr(:if, true, 1)
(if (= x 1) (println "yes")) ||| Any["if", Any["=", "x", "1"], Any["println", "\"yes\""]] ||| Expr(:if, :(==(x, 1)), :(println("yes")))
(if true 1 0) ||| Any["if", "true", "1", "0"] ||| :(true ? 1 : 0)
(if (% y 3) (println "yes") (println "no")) ||| Any["if", Any["%", "y", "3"], Any["println", "\"yes\""], Any["println", "\"no\""]] ||| Expr(:if, :(%(y, 3)), :(println("yes")), :(println("no")))

Def
; (def) should cause error
; (def x) should cause error
(def x 1) ||| Any["def", "x", "1"] ||| :(x = 1)
(def x (f 5)) ||| Any["def", "x", Any["f", "5"]] ||| :(x = f(5))

Let
; (let) should cause error
(let []) ||| Any["let", Any[:vect]] ||| Expr(:let, Expr(:block))
(let [] x) ||| Any["let", Any[:vect], "x"] ||| Expr(:let, Expr(:block, :x))
; (let [x] x) should cause error
(let [x 1] x) ||| Any["let", Any[:vect, "x", "1"], "x"] ||| :(let x=1; x end)
(let [x 1 y (+ x 1)] (+ y x)) ||| Any["let", Any[:vect, "x", "1", "y", Any["+", "x", "1"]], Any["+", "y", "x"]] ||| :(let x=1,y=x+1; y+x end)

Fn
;(fn) should throw error
(fn []) ||| Any["fn", Any[:vect]] ||| :(()->nothing)
(fn [] x) ||| Any["fn", Any[:vect], "x"] ||| :(()->x)
(fn [x] x) ||| Any["fn", Any[:vect, "x"], "x"] ||| :((x,)->x)
(fn [x y] (+ x y)) ||| Any["fn", Any[:vect, "x", "y"], Any["+", "x", "y"]] ||| :((x,y)->x+y)
(fn [x y] (inc x) (+ x y)) ||| Any["fn", Any[:vect, "x", "y"], Any["inc", "x"], Any["+", "x", "y"]] ||| :(function(x,y) inc(x); x+y end)
(fn f [x] x) ||| Any["fn", "f", Any[:vect, "x"], "x"] ||| :(function f(x) x end)


Typing forms (::, curly)
;; Contains special forms that derive from julia, not clojure
(:: x Int) ||| Any["::", "x", "Int"] ||| :(x::Int)
; there are a lot of issues with expr equality in julia.
(.x symbol) ||| Any[".x", "symbol"] ||| :(symbol.x())


Clojure Special Forms
(quote x) ||| Any["quote", "x"] ||| Expr(:quote, :x)
; function literals ALWAYS have a block in the AST, so we have to Explicitly describe the s-expr.
(let [x 1] x) ||| Any["let", Any[:vect, "x", "1"], "x"] ||| :(let x=1; x end)
(let [x 1 y 2] (+ x y)) ||| Any["let", Any[:vect, "x", "1", "y", "2"], Any["+","x","y"]] ||| :(let x=1,y=2; x+y end)