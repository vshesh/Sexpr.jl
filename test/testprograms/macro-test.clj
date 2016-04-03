(module MacroTest
  
  (defmacro m [x]
    `(if ~x 1 0))

  (defn f [x]
    (@m x)))
