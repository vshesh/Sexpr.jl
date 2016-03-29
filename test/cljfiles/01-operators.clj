Basic operator call syntax tests
;; This file contains tests for the math, bitmath, and comparison operators
;; present in julia. It does NOT test for builtin clojure math expressions,
;; like `mod` or `not=`.
;; Short of trying to read atoms, this is the simplest test for the reader.

Math operators
; this test also works, it just surfaces a wierd auto-eval behavior inside julia.
; (+ 1) ||| Any["+", "1"] ||| :(+1)
(+ 1 2) ||| Any["+", "1", "2"] ||| :(1 + 2)
(- 1) ||| Any["-", "1"] ||| :(- 1)
(- 1 2) ||| Any["-", "1", "2"] ||| :(1 - 2)
(* 1 2) ||| Any["*", "1", "2"] ||| :(1 * 2)
(/ 1 2) ||| Any["/", "1", "2"] ||| :(1 / 2)
(\ 1 2) ||| Any["\\", "1", "2"] ||| :(1 \ 2)
(^ 2 3) ||| Any["^", "2", "3"] ||| :(2 ^ 3)
(% 2 3) ||| Any["%", "2", "3"] ||| :(2 % 3)

Bitmath operators
;; At some point these need to be changed to clojure's actual bit operations.
;; eg bit-not bit-or bit-and etc.
;(~ 1) ||| Any["~", "1"] ||| :(~1)
(& 1 0) ||| Any["&", "1", "0"] ||| :(1 & 0)
(| 1 0) ||| Any["|", "1", "0"] ||| :(1 | 0)
($ 1 0) ||| Any["\$", "1", "0"] ||| :(1 $ 0)
(>> 2 1) ||| Any[">>", "2", "1"] ||| :(2 >> 1)
(<< 2 1) ||| Any["<<", "2", "1"] ||| :(2 << 1)
(>>> 2 1) ||| Any[">>>", "2", "1"] ||| :(2 >>> 1)

Comparison Operators
(== 1 0) ||| Any["==", "1", "0"] ||| :(==(1,0))
(!= 1 0) ||| Any["!=", "1", "0"] ||| :(!=(1,0))
(< 1 0) ||| Any["<", "1", "0"] ||| :(<(1,0))
(> 1 0) ||| Any[">", "1", "0"] ||| :(>(1,0))
(<= 1 0) ||| Any["<=", "1", "0"] ||| :(<=(1,0))
(>= 1 0) ||| Any[">=", "1", "0"] ||| :(>=(1,0))
