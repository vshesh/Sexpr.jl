Special Forms

And/Or
true && false ||| (and true false)
false || false ||| (or false false)

Empty List
() ||| ()

Literals
[1, 2, 3] ||| [1 2 3]
Dict(1 => 2, 3 => 4) ||| {1 2 3 4}

:call
+(1,1) ||| (+ 1 1)
>(1,2) ||| (> 1 2)
f(5,6) ||| (f 5 6)

:block
begin end ||| nil
begin 1 end ||| 1
begin 1 + 1 end ||| (+ 1 1)
begin x + 1; x + 5 end ||| (do (+ x 1) (+ x 5))

:if
if true 1 end ||| (if true 1)
if true 1 else 0 end ||| (if true 1 0)
if true 1 elseif false 0 else 2 end ||| (if true 1 (if false 0 2))

:comparison
1 > 2 ||| (> 1 2)
1 != 3 ||| (!= 1 3)

:let
let x=1, y=2; end ||| (let [x 1 y 2] nil)
let x=1, y=x+1; y end ||| (let [x 1 y (+ x 1)] y)
let x=1, y=f(g(x)); f(y, true) end ||| (let [x 1 y (f (g x))] (f y true))

:(=)
x = 5 ||| (def x 5)

:->
x -> x ||| (fn [x] x)
(x,y) -> x ||| (fn [x y] x)

:function
function() end ||| (fn [] nil)
function(x) x + 1 end ||| (fn [x] (+ x 1))
function(x) x+1;x+5; end ||| (fn [x] (+ x 1) (+ x 5))

:call>:. (dot call syntax)
x.y() ||| (x.y)
x().y() ||| ((. (x) y))
x().y.z(1,2) ||| ((. (x) y.z) 1 2)

:. (dot access)
x.y.z ||| x.y.z
x(1,2).y.z ||| (. (x 1 2) y.z)

:: (type)
x::Int ||| x::Int
x::Int::Int64 ||| x::Int::Int64
x::Array{Int} ||| (:: x (curly Array Int))

:macrocall
@m 1 ||| (@m 1)
@m [1, 2, 3] ||| (@m [1 2 3])
@m (:html, Dict(1=>2)) ||| (@m (:html {1 2}))
@m 1 2 3 ||| (@m 1 2 3)
@m (:if, true, 1, 0) ||| (@m (if true 1 0))
