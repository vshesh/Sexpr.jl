Atoms
;; File: atoms.clj
;; Author: Vishesh Gupta
;; atoms tests. Ensures that basic atoms read into exactly the forms that they
;; are expected to be.

Nil and Booleans
nil ||| "nil" ||| nothing
true ||| "true" ||| true
false ||| "false" ||| false

Numbers
1 ||| "1" ||| 1
12318231209381 ||| "12318231209381" ||| 12318231209381
-19123187345674 ||| "-19123187345674" ||| -19123187345674
5r123124 ||| "5r123124" ||| 4789
5r-123124 ||| "5r-123124" ||| -4789
2349193123/1390123123 ||| "2349193123/1390123123" ||| 2349193123//1390123123
-8/10 ||| "-8/10" ||| -8//10
;; floats
3e5 ||| "3e5" ||| 300000.0
-3e5 ||| "-3e5" ||| -300000.0
3.124 ||| "3.124" ||| 3.124
-3.124 ||| "-3.124" ||| -3.124
3.124e5 ||| "3.124e5" ||| 312400.0
-3.124e5 ||| "-3.124e5" ||| -312400.0
3e-5 ||| "3e-5" ||| 3.0e-5
-3e-5 ||| "-3e-5" ||| -3.0e-5
3.124e-5 ||| "3.124e-5" ||| 3.124e-5
-3.124e-5 ||| "-3.124e-5" ||| -3.124e-5
;; int stress test
9 ||| "9" ||| 9
999999999999 ||| "999999999999" ||| 999999999999
999999999999999999999999 ||| "999999999999999999999999" ||| 999999999999999999999999
999999999999999999999999999999999999 ||| "999999999999999999999999999999999999" ||| 999999999999999999999999999999999999
999999999999999999999999999999999999999 ||| "999999999999999999999999999999999999999" ||| 999999999999999999999999999999999999999


Characters
\a ||| "\\a" ||| 'a'
\b ||| "\\b" ||| 'b'
\c ||| "\\c" ||| 'c'
\d ||| "\\d" ||| 'd'
\e ||| "\\e" ||| 'e'
\f ||| "\\f" ||| 'f'
\g ||| "\\g" ||| 'g'
\h ||| "\\h" ||| 'h'
\i ||| "\\i" ||| 'i'
\j ||| "\\j" ||| 'j'
\k ||| "\\k" ||| 'k'
\l ||| "\\l" ||| 'l'
\m ||| "\\m" ||| 'm'
\n ||| "\\n" ||| 'n'
\o ||| "\\o" ||| 'o'
\p ||| "\\p" ||| 'p'
\q ||| "\\q" ||| 'q'
\r ||| "\\r" ||| 'r'
\s ||| "\\s" ||| 's'
\t ||| "\\t" ||| 't'
\u ||| "\\u" ||| 'u'
\v ||| "\\v" ||| 'v'
\w ||| "\\w" ||| 'w'
\x ||| "\\x" ||| 'x'
\y ||| "\\y" ||| 'y'
\z ||| "\\z" ||| 'z'
\1 ||| "\\1" ||| '1'
\2 ||| "\\2" ||| '2'
\3 ||| "\\3" ||| '3'
\4 ||| "\\4" ||| '4'
\5 ||| "\\5" ||| '5'
\6 ||| "\\6" ||| '6'
\7 ||| "\\7" ||| '7'
\8 ||| "\\8" ||| '8'
\9 ||| "\\9" ||| '9'
\0 ||| "\\0" ||| '0'
\* ||| "\\*" ||| '*'
; escape sequence characters.
\newline ||| "\\newline" ||| '\n'
\space ||| "\\space" ||| ' '
\tab ||| "\\tab" ||| '\t'
\formfeed ||| "\\formfeed" ||| '\f'
\backspace ||| "\\backspace" ||| '\b'
\return ||| "\\return" ||| '\r'


Strings
"a" ||| "\"a\"" ||| "a"
"\"" ||| "\"\\\"\"" ||| "\""
"!@#$%!%#!" ||| "\"!@#\$%!%#!\"" ||| "!@#\$%!%#!"
"`1234567809-=~!@#$%^*(&)_+qwerrtweurpiouy[]{}\\|asdfghjkl;:\"zxcvbn,m./<>?" ||| "\"`1234567809-=~!@#\$%^*(&)_+qwerrtweurpiouy[]{}\\\\|asdfghjkl;:\\\"zxcvbn,m./<>?\"" ||| "`1234567809-=~!@#\$%^*(&)_+qwerrtweurpiouy[]{}\\|asdfghjkl;:\"zxcvbn,m./<>?"
"F#p.PqG4hqY=+|n" ||| "\"F#p.PqG4hqY=+|n\"" ||| "F#p.PqG4hqY=+|n"
":FfJzo!.3c^.U+B" ||| "\":FfJzo!.3c^.U+B\"" ||| ":FfJzo!.3c^.U+B"
"(xNQ@u&_Tuz^<>%" ||| "\"(xNQ@u&_Tuz^<>%\"" ||| "(xNQ@u&_Tuz^<>%"
"EiEDwpo7L%G.vu8" ||| "\"EiEDwpo7L%G.vu8\"" ||| "EiEDwpo7L%G.vu8"
"Jc[Yu#=6M8$7(3b" ||| "\"Jc[Yu#=6M8\$7(3b\"" ||| "Jc[Yu#=6M8\$7(3b"
"L1Sq<;;;/.>I+P!va?" ||| "\"L1Sq<;;;/.>I+P!va?\"" ||| "L1Sq<;;;/.>I+P!va?"
"3X]8n]Gi*A@Pn:O" ||| "\"3X]8n]Gi*A@Pn:O\"" ||| "3X]8n]Gi*A@Pn:O"
"FG4=Dm78**0Be~0s!\"" ||| "\"FG4=Dm78**0Be~0s!\\\"\"" ||| "FG4=Dm78**0Be~0s!\""
"vy;_ajA9!D{0uR//" ||| "\"vy;_ajA9!D{0uR//\"" ||| "vy;_ajA9!D{0uR//"

Keywords
:12 ||| ":12" ||| Expr(:quote, symbol("12"))
:1238123 ||| ":1238123" ||| Expr(:quote, symbol("1238123"))
:x ||| ":x" ||| Expr(:quote, :x)
:foobar ||| ":foobar" ||| Expr(:quote, :foobar)
:foo-bar ||| ":foo-bar" ||| Expr(:quote, :foo¯bar)
:foo-bar!? ||| ":foo-bar!?" ||| Expr(:quote, :foo¯bar!ʔ)
:foo-b__ar!_*?94810293123 ||| ":foo-b__ar!_*?94810293123" ||| Expr(:quote, :foo¯b__ar!_°ʔ94810293123)
::f!?:++o*o-b_a-xc_r!+>>>><<<<<*? ||| "::f!?:++o*o-b_a-xc_r!+>>>><<<<<*?" ||| Expr(:quote, :¦f!ʔ¦⁺⁺o°o¯b_a¯xc_r!⁺▻▻▻▻∠∠∠∠∠°ʔ)

Symbols
x ||| "x" ||| :x
X ||| "X" ||| :X
foobar ||| "foobar" ||| :foobar
foo-bar ||| "foo-bar" ||| :foo¯bar
foo-bar? ||| "foo-bar?" ||| :foo¯barʔ
foo__bar? ||| "foo__bar?" ||| :foo__barʔ
FOOBAR_foobar_-foobaar1? ||| "FOOBAR_foobar_-foobaar1?" ||| :FOOBAR_foobar_¯foobaar1ʔ
FOOBAR!!!!!!!! ||| "FOOBAR!!!!!!!!" ||| :FOOBAR!!!!!!!!
fOo-bOr!!!!!!?12424+ ||| "fOo-bOr!!!!!!?12424+" ||| :fOo¯bOr!!!!!!ʔ12424⁺
foo-b_a'_r:!+.*? ||| "foo-b_a'_r:!+.*?" |||  :(foo¯b_a′_r¦!⁺.°ʔ)
@macro ||| "@macro" ||| symbol("@macro")
x@y ||| "x@y" ||| symbol("x@y")
; random 15 char symbols.
a5rNtvlIOveaQBQL ||| "a5rNtvlIOveaQBQL" ||| :a5rNtvlIOveaQBQL
aINNo0T2bmf7N8PE ||| "aINNo0T2bmf7N8PE" ||| :aINNo0T2bmf7N8PE
aZjT35MqHjNNcKYe ||| "aZjT35MqHjNNcKYe" ||| :aZjT35MqHjNNcKYe
a17wCv639cgcEjRV ||| "a17wCv639cgcEjRV" ||| :a17wCv639cgcEjRV
aHQmVVHhYaEuYrrL ||| "aHQmVVHhYaEuYrrL" ||| :aHQmVVHhYaEuYrrL
awGoUtSrYncOYjno ||| "awGoUtSrYncOYjno" ||| :awGoUtSrYncOYjno
ah1mrXbAJ1T1G9Hv ||| "ah1mrXbAJ1T1G9Hv" ||| :ah1mrXbAJ1T1G9Hv
aF3AExS1D7K3qTE3 ||| "aF3AExS1D7K3qTE3" ||| :aF3AExS1D7K3qTE3
ajIDc27JWXGzie1U ||| "ajIDc27JWXGzie1U" ||| :ajIDc27JWXGzie1U
; special typing syntax
a::Int64 ||| "a::Int64" ||| :(a::Int64)
a::Int::Int64 ||| "a::Int::Int64" ||| :(a::Union{Int, Int64})
a/b ||| "a/b" ||| :(a.b)
a/b/c/d/e ||| "a/b/c/d/e" ||| :(a.b.c.d.e)
a.b ||| "a.b" ||| :(a.b)
a.b.c.d.e ||| "a.b.c.d.e" ||| :(a.b.c.d.e)
; operators
+ ||| "+" ||| :+
/ ||| "/" ||| :/
>> ||| ">>" ||| :>>
; builtins
mod ||| "mod" ||| :%
= ||| "=" ||| :(==)
