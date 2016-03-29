Atom Testing
# atom testing is less of a big deal here because julia recognizes its own
# types and has written its own parser (so I don't need to check that the
# parser works, just that the logic that I'm using makes sense)

Nil
# I'm still not clear on when each of these is supposed to be used where, and
# what exactly I'd be processing in this situation.
nothing ||| nil
:nothing ||| :nothing

Boolean
true ||| true
false ||| false

Numbers
1 ||| 1
12318231209381 ||| 12318231209381
-19123187345674 ||| -19123187345674
2349193123//1390123123 ||| 2349193123/1390123123
-8//10 ||| -8/10

# I'm not too concerned how the numbers look since I read them with julia's
# parse function, so I would hope that julia would maintain its own internal
# consistency.
300000.0 ||| 300000.0
3.124e-5 ||| 3.124e-5

Characters
'a' ||| \a
'1' ||| \1
'\n' ||| \newline
'\f' ||| \formfeed
'\t' ||| \tab
' ' ||| \space
'\b' ||| \backspace
'\r' ||| \return

Strings
"a" ||| "a"
"\"" ||| "\""
"\n" ||| "\n"
"`1234567809-=~!@#\$%^*(&)_+qwerrtweurpiouy[]{}\\|asdfghjkl;:\"zxcvbn,m./<>?" ||| "`1234567809-=~!@#$%^*(&)_+qwerrtweurpiouy[]{}\\|asdfghjkl;:\"zxcvbn,m./<>?" ||| "`1234567809-=~!@#\$%^*(&)_+qwerrtweurpiouy[]{}\\|asdfghjkl;:\"zxcvbn,m./<>?"

Keywords
:12 ||| :12
:x ||| :x
:hello_dad ||| :hello_dad

Symbols
x ||| x
x° ||| x*
foo¯b_a′_r¦!⁺°ʔ ||| foo-b_a'_r:!+*?
a5rNtvlIOveaQBQL ||| a5rNtvlIOveaQBQL
aINNo0T2bmf7N8PE ||| aINNo0T2bmf7N8PE
aZjT35MqHjNNcKYe ||| aZjT35MqHjNNcKYe
a17wCv639cgcEjRV ||| a17wCv639cgcEjRV
aHQmVVHhYaEuYrrL ||| aHQmVVHhYaEuYrrL
awGoUtSrYncOYjno ||| awGoUtSrYncOYjno
ah1mrXbAJ1T1G9Hv ||| ah1mrXbAJ1T1G9Hv
aF3AExS1D7K3qTE3 ||| aF3AExS1D7K3qTE3
ajIDc27JWXGzie1U ||| ajIDc27JWXGzie1U
+ ||| +
/ ||| /
