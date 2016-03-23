function camelize(dashed)
    "Converts dashed-name to dashedName"
    re.sub("-(\\w)",((s,)->second(s.group(0).upper())),dashed)
end

function dasherize(camel)
    "Converts camelCase to camel-case and HTTPResponse to http-response.\n  Not fully reversible by camelize\n  eg: (camelize(dasherize HTTPResponse)) -> httpResponse"
    re.sub("((?<=[a-z0-9])[A-Z]|(?!^)[A-Z](?=[a-z]))","-\\1",camel).lower()
end

function translate(xf,yf)
    "Takes a function of one variable for computing the x coordinate\n  and the y coordinate and returns a function that will generate a\n  string of how much to translate an element "
    (d,)->"translate(" + str(xf(d)) + ", " + str(yf(d)) + ")"
end

function rotate(rf)
    "Takes a function rf of one variable that returns the rotation amount\n  in degrees and returns a function that will generate the rotation string\n  for how much to rotate an element."
    (d,)->"rotate(" + str(rf(d)) + "deg)"
end

function boost(k,r)
    "Logistic 1:1 mapping (approximately) for the range.\n  If desired output is (-100, 100) then range is 200.\n  k controls how steep the logistic function is - the % coverage of the\n  logistic bump is governed by 2log[1/2 (1+E^k)]/k -1.\n  10 is a good default if you're confused."
    (x,)->r * (1 / (1 + math.e ^ ((-1 * k * x) / r)) - 0.5)
end

function linear¯map(domain,range)
    "returns native mapping from domain to range in a linear manner."
    let a = first(domain), b = second(domain), c = first(range), d = second(range)
        (x,)->c + (d - c) * ((x - a) / (b - a))
    end
end

function max¯brighter¯gamma(n,l)
    "Given n depth of a hierarchical layout (eg partition, sunburst),\n  will compute the maximum multiplier per level (gamma constant)\n  allowed for that lightness.\n  The formula is (max-allowed-lightness/l)^(1/n).\n  For the default max lightness of 120, beyond initial lightnesses (l) of 20,\n  the function is almost linear."
    (120 / l) ^ (1 / n)
end

function max¯darker¯gamma(n,l)
    "Given n depth of a hierarchical layout (eg partition, sunburst),\n  will compute the maximum magnitude of the multiplier per level\n  (gamma constant) allowed for that lightness.\n\n  The formula is (min-allowed-lightness/l)^(-1/n).\n  For the default min lightness of 10, beyond initial lightnesses (l) of 20,\n  the function is almost linear."
    (10 / l) ^ (-1 / n)
end

function adjust¯index(T,d)
    let nchild = d.parent.children.length, i = d.parent.children.indexOf(d)
        if nchild == 1
            0
        else 
            ((i / (nchild - 1) - 0.5) * T * d.parent.dx) / math.sqrt(d.depth)
        end
    end
end

function hierarchical¯color(ht,ct,lt)
    function (d,)
        if d.parent
            let pcolor = d.parent.color
                setv(d.color,d3.hcl(ht(pcolor.h,d),ct(pcolor.c,d),lt(pcolor.l,d)))
            end
        end
        d.color
    end
end

x¯hue¯y¯lightness = hierarchical¯color(((ph,d)->index¯adjust(50,d)),((pc,d)->pc),((pl,d)->pl * 1.25))

