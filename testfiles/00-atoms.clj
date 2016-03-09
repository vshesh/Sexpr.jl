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
123124r5 ||| "123124r5" ||| 4789
-123124r5 ||| "-123124r5" ||| -4789
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


