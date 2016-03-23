(defmacro m [x] 1)

(defmacro unit-time [value unit]
  `(* ~value
    ~(@match unit
      (do
        :s 1
        :m 60
        :h 3600
        :d 86400
        :ms 1/1000
        :us 1/1000000))))
        


        
        
        
