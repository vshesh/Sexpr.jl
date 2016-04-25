(module MacroTest
  
  (defmacro html [t]
    (if (isa (first t) QuoteNode)
      (let [tag (first t)
            attrs (if (and (> (length t) 2) (isa (second t) Dict)) (second t) {})]
        `(m ~(string tag) ~attrs ~@(map html (drop 2 t))))
      (if (isa (first t) Symbol)
        `((. m component) ~(string (first t)) ~(second t))
        `(m "div" (string "Error generating tag: " ~t)))))

  (defn view [vm]
    (html [:div {:class "hello"}])))
