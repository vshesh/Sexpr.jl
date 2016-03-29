Atom Testing

# I'm still not clear on when each of these is supposed to be used where, and
# what exactly I'd be processing in this situation.
Nil
nothing ||| "nil"
:nothing ||| "nil"

Boolean
true ||| "true"
false ||| "false"

Numbers
1 ||| "1"
12318231209381 ||| "12318231209381"
-19123187345674 ||| "-19123187345674"
2349193123//1390123123 ||| "2349193123/1390123123"
-8//10 ||| "-8/10"

# I'm not too concerned how the numbers look since I read them with julia's
# parse function, so I would hope that julia would maintain its own internal
# consistency.
300000.0 ||| "300000.0"
3.124e-5 ||| "3.124e-5"

Characters
'a' ||| "\\a"
'1' ||| "\\1"
'\n' ||| "\\newline"
'\f' ||| "\\formfeed"
'\t' ||| "\\tab"
' ' ||| "\\space"
'\b' ||| "\\backspace"
'\r' ||| "\\return"

