; ------------------------- GENERAL HELPER FUNCTIONS  -------------------------
(defn camelize [dashed]
  "Converts dashed-name to dashedName"
  (re.sub "-(\\w)" (fn [s] (second (.upper (.group s 0)))) dashed))

(defn dasherize [camel]
  "Converts camelCase to camel-case and HTTPResponse to http-response.
  Not fully reversible by camelize
  eg: (camelize(dasherize HTTPResponse)) -> httpResponse"
  (.lower (re.sub "((?<=[a-z0-9])[A-Z]|(?!^)[A-Z](?=[a-z]))"
                  "-\\1"
                  camel)))

; -------------------------   VIZ HELPER FUNCTIONS    -------------------------

; --- PROPERTY functions (translate, rotate, arcs, etc)

(defn translate [xf yf]
  "Takes a function of one variable for computing the x coordinate
  and the y coordinate and returns a function that will generate a
  string of how much to translate an element "
  (fn [d] (+ "translate(" (str (xf d)) ", " (str (yf d)) ")")))

(defn rotate [rf]
  "Takes a function rf of one variable that returns the rotation amount
  in degrees and returns a function that will generate the rotation string
  for how much to rotate an element."
  (fn [d] (+ "rotate(" (str (rf d)) "deg)")))

; --- SCALE functions (d3 scales, and some custom functions
;                       for native calculations)

;-1-1 scales (symmetric scales about the origin)
(defn boost[k r]
  "Logistic 1:1 mapping (approximately) for the range.
  If desired output is (-100, 100) then range is 200.
  k controls how steep the logistic function is - the % coverage of the
  logistic bump is governed by 2log[1/2 (1+E^k)]/k -1.
  10 is a good default if you're confused."
  (fn [x] (* r (- (/ 1 (+ 1 (^ math.e (/ (* -1 k x) r)))) 0.5))))

; 0-1 scales
(defn linear-map [domain range]
  "returns native mapping from domain to range in a linear manner."
  (let [a (first domain)
        b (second domain)
        c (first range)
        d (second range)]
    (fn [x]
      (+ c (* (- d c) (/ (- x a) (- b a)))))))

;; (fn pow-map [exp [a b] [c d]]
;;   "returns native mapping from domain to range with a given exponent"
;;   (fn [x]
;;     (+ c (* (- d c) (^ (/ (- x a) (- b a)) exp)))))

; --- COLOR functions (lots of heuristical assessments)

; note: brighter/darker not exactly symmetric!
;       i.e (max-brigher-gamma n l) != -1 * (max-darker-gamma n l)
; however flipping the exponent will be a close approximate.

; max appropriate hcl lightness is 120
; (beyond that you max out at many chromas)
(defn max-brighter-gamma [n l]
  "Given n depth of a hierarchical layout (eg partition, sunburst),
  will compute the maximum multiplier per level (gamma constant)
  allowed for that lightness.
  The formula is (max-allowed-lightness/l)^(1/n).
  For the default max lightness of 120, beyond initial lightnesses (l) of 20,
  the function is almost linear."
  (^ (/ 120 l) (/ 1 n)))

; min appropriate lightness for hcl is 10, otherwise it's basically black.
(defn max-darker-gamma [n l]
  "Given n depth of a hierarchical layout (eg partition, sunburst),
  will compute the maximum magnitude of the multiplier per level
  (gamma constant) allowed for that lightness.

  The formula is (min-allowed-lightness/l)^(-1/n).
  For the default min lightness of 10, beyond initial lightnesses (l) of 20,
  the function is almost linear."
  (^ (/ 10 l) (/ -1 n)))

(defn adjust-index [T d]
  (let [nchild d.parent.children.length
        i (d.parent.children.indexOf d)]
    (if (= nchild 1) 0
      (/ (* (- (/ i (- nchild 1)) 0.5) T d.parent.dx)
         (math.sqrt d.depth)))))

(defn hierarchical-color [ht ct lt]
  (fn [d]
    (if d.parent
      (let [pcolor d.parent.color]
        (setv d.color
              (d3.hcl (ht pcolor.h d)
                      (ct pcolor.c d)
                      (lt pcolor.l d)))))
    d.color))

(def x-hue-y-lightness
  (hierarchical-color
    (fn [ph d] (index-adjust 50 d))
    (fn [pc d] pc)
    (fn [pl d] (* pl 1.25))))
    

