# File: formatter.jl
# Author: Vishesh Gupta
# Created: 19 April 2016

"""
The purpose of this module is to be a code formatter for expression objects.
It seems that surgically inserting a new definition into a Base function
like string() or show() is not possible because there's no way to reference
the outside definition because you have to overshadow it to override it.
So.... manual definition it is.
It's probably for the best - relying on Julia's shaky expression printing
semantics isn't even a good idea to begin with, since Julia is not a 1.0 language
and things are likely to change before they settle on any kind of s-expression.
"""
module Formatter

export tostring

INDENT_WIDTH = 2

macro indent(e)
  quote
    string(repeat(" ", level*$INDENT_WIDTH), $e)
  end
end

macro rawindent(addon)
  :(repeat(" ", (level+$addon)*$INDENT_WIDTH))
end

"""
tostring(x::Any)
takes an ast node (basically, anything) and returns a string version
of it by using @sprintf (which will play nicely with anyone who overrides
show for their custom objects. There are no custom objects in the project
as of now, but if there ever have to be (thanks to hash dispatch) it might
be a good idea to support that).

The `@sprintf` macro is only used in cases where the type of the expression
is not known. In all other cases where the type is known (such as Void, Bool,
Char, Int, Float, AbstractString, QuoteNode, Symbol, Expr, etc), there is a
special version of the method written to accomodate it and produce correct
formatting and such.
"""
function tostring(x, level::Int=0) end

tostring(x::Void, level::Int=0) = @indent "nothing"
tostring(x::Bool, level::Int=0) = @indent string(x)
tostring(x::Union{Int, Int8, Int16, Int32, Int64, Int128}, level::Int=0) =
  @indent string(x)
tostring(x::Union{UInt, UInt8, UInt16, UInt32, UInt64, UInt128}, level::Int=0) =
  @indent string("0x",base(16,x))
tostring(r::Rational, level::Int=0) = @indent string(r)
tostring(p::Pair, level::Int=0) =
  @indent string(tostring(p[1])," => ",tostring(p[2]))

tostring(c::Char, level::Int=0) = @indent string("'", c ,"'")
tostring(s::AbstractString, level::Int=0) = @indent string("\"", s, "\"")

tostring(x::QuoteNode, level::Int=0) =
  @indent(if isa(x.value, Symbol)
    string(":", tostring(x.value))
  # this branch should never activate, really
  else
    string(":(",tostring(x.value),")")
  end)
tostring(s::Symbol, level::Int=0) = @indent string(s)

tostring(t::Tuple, level::Int=0) =
  @indent string("(", join(map(x -> tostring(x, 0), t), ","), ")")
tostring(t::Array, level::Int=0) =
  @indent string("[", join(map(x -> tostring(x, 0), t), ","), "]")
tostring(t::Dict, level::Int=0) =
  @indent string("Dict(", "\n",join(map(x -> tostring(x, level+1), t), ",\n"), ")")


function tostring(ex::Expr, level::Int=0)
  # special atoms
  if ex.head == ://
    @indent string(ex.args[1], "//", ex.args[2])
  elseif ex.head == :(=>)
    @indent string(tostring(ex.args[1]), " => ", ex.args[2])

  # Collections
  elseif ex.head == :tuple
    @indent string("(", join(map(tostring, ex.args), ","), ")")
  elseif ex.head == :vect
    @indent string("[", join(map(tostring, ex.args), ","), "]")
  elseif ex.head == :call && ex.args[1] == :Dict
    @indent string("Dict(",
                   "\n",
                   join(map(x -> tostring(x, level+1), ex.args[2:end]), ",\n"),
                   ")")

  # Macro forms
  # head :macro is taken care of with :function since it's the same.
  elseif ex.head == :quote
    if isa(ex.args[1], Symbol)
      @indent string(":", tostring(ex.args[1]))
    else
      @indent string(":(", join(map(tostring, ex.args), "\n"), ")")
    end

  elseif ex.head == :$
    if isa(ex.args[1], Symbol)
      @indent string("\$", tostring(ex.args[1]))
    else
      @indent string("\$(", tostring(ex.args[1]), ")")
    end

  elseif ex.head == :...
    @indent string(tostring(ex.args[1]), "...")

  elseif ex.head == :block
    if length(ex.args) == 1
      tostring(ex.args[1], level)
    else
      string(@indent("begin\n"),
             join(map(x -> @indent(tostring(x, level+1)), ex.args), "\n"),
             "\n",
             @indent("end"))
    end

  elseif ex.head == :if
    string(@indent("if "),
           tostring(ex.args[1]), "\n",
           tostring(ex.args[2], level+1),
           "\n",
           if length(ex.args) > 2
             string(@indent("else\n"),
                    tostring(ex.args[3], level+1), "\n",
                    @indent("end"))
           else @indent("end")
           end)

  elseif ex.head == :comparison
    @indent string("(",join(map(x->tostring(x, level), ex.args), " "),")")

  elseif ex.head == :let
    string(@indent("let "),
           join(map(tostring, ex.args[2:end]), ", "), "\n",
           tostring(ex.args[1], level+1), "\n",
           @indent("end"))

  elseif ex.head == :function || ex.head == :macro
    string(@indent(string(ex.head)), " ", tostring(ex.args[1]), "\n",
           join(map(x->tostring(x,level+1), ex.args[2].args),"\n"), "\n",
           @indent("end"))

  elseif ex.head == :->
    string(tostring(ex.args[1], level), " -> ", tostring(ex.args[2]))

  elseif ex.head == :(=)
    string(tostring(ex.args[1], level), " = ", tostring(ex.args[2]))

  # JULIA Special forms
  # ref/aget related
  elseif ex.head == :ref
    @indent string(tostring(ex.args[1]),
                   "[",
                   join(map(tostring, ex.args[2:end]), ","),
                   "]")
  elseif ex.head == :(:)
    @indent join(map(tostring, ex.args), ":")

  #module related
  elseif ex.head == :module
    string(@indent("module "),
           ex.args[2], "\n",
           join(map(x->tostring(x,level+1), ex.args[3].args[3:end]), "\n\n"),
           "\n",
           @indent("end"))
  elseif ex.head in (:import, :using)
    @indent string(tostring(ex.head), " ", join(map(tostring, ex.args), "."))

  elseif ex.head == :export
    @indent string("export ", join(map(tostring, ex.args), ","))

  # . syntax
  elseif ex.head in (:., :(::), :curly, :&&, :||)
    @indent @sprintf("%s", ex)

  elseif ex.head == :call || ex.head == :macrocall
    string(tostring(ex.args[1], level), "(",
           join(map(tostring, ex.args[2:end]), ", "), ")")

  # format-like expressions
  elseif ex.head == :toplevel
    join(map(x->tostring(x,level), ex.args), "\n")

  else
    # I could default support things with @sprintf("%s", ex),
    # but i think that it is better to directly support the forms that
    # are compatible, so that it's clear when something's wrong.
    "ERROR: could not print $ex :ERROR"
  end
end


html(x::Any) = string(x)
function html(v::Union{Array, Tuple})

  t = if isa(v[1], Symbol) string(v[1]) else v[1] end

  # get id
  id = match(r"#(\w+)\b", t)
  id = if id != nothing id[1] else nothing end

  # strip classes
  s = split(t, '.')
  tagname = split(s[1], '#')[1]
  classes = join(map(x->split(x, '#')[1], s[2:end]), " ")

  return "<$(tagname)$(
    if id != nothing " id=\"$(id)\"" else "" end) class=\"$(classes)\">$(
    join(map(html, v[2:end]),""))</$(tagname)>"
end


mapcat(f, args...) = vcat(map(f, args...)...)
interpose(inter, seq) = mapcat((e) -> [e, inter], seq)[1:end-1]
interpose(i1, i2, seq) = mapcat((e) -> [e, i1, i2], seq)[1:end-2]
prependcat(i, seq) = mapcat((e) -> [i, e], seq)
prependcat(i1,i2,seq) = mapcat((e) -> [i1, i2, e], seq)


const tags = Dict(
  :paren => "span.punctuation.paren",
  :comma => "span.punctuation.comma",

  :nil => "span.constant.nil",
  :bool => "span.constant.bool",
  :number => "span.constant.number",
  :hexnumber => "span.constant.number.hex",
  :decnumber => "span.constant.number.decimal",
  :rational => "span.constant.rational",
  :char => "span.constant.char",
  :string => "span.constant.string",
  :keyword => "span.constant.keyword",
  
  :variable => "span.variable",
  # reserved words in a language, like "if"
  :reserved => "span.reserved",

  :quote => "span.quoted",
  :unquote => "span.unquoted",
  
  # has so many interpretations in so many places...
  :dot => "span.operator.dot",
  # :, ::, =>, ...
  :opmisc => "span.operator.misc",
  # +, -, *, /, %, ^
  :oparith => "span.operator.arithmetic",
  # ~, &, |, $, <<, >>, >>>
  :opbit => "span.operator.bitmath",
  # ==, <=, >=, <, >, !=,
  :opcomp => "span.operator.comparison",

  :pair => "span.ds.pair",
  :tuple => "span.ds.tuple",
  :vect => "span.ds.vect",
  :dict => "span.ds.dict",
  
  # SPECIAL forms
  :block => "span.block"
)

function tohtml(x, level::Int=0) end

tohtml(x::Void, level::Int=0) = (tags[:nil], "nothing")
tohtml(x::Bool, level::Int=0) = (tags[:bool], string(x))
tohtml(x::Union{Int, Int8, Int16, Int32, Int64, Int128}, level::Int=0) =
  (tags[:number], string(x))
tohtml(x::Union{UInt, UInt8, UInt16, UInt32, UInt64, UInt128}, level::Int=0) =
  (tags[:hexnumber], string("0x",base(16,x)))
tohtml(x::AbstractFloat, level::Int=0) =
  (tags[:decnumber], string(x))
tohtml(r::Rational, level::Int=0) = (tags[:rational], string(r))
tohtml(p::Pair, level::Int=0) =
  (tags[:pair],
    tohtml(p[1]), " ",
    (tags[:opmisc], "=>"), " ",
    tohtml(p[2]))

tohtml(c::Char, level::Int=0) = (tags[:char], string("'", c ,"'"))
tohtml(s::AbstractString, level::Int=0) = (tags[:string], string("\"", s, "\""))

tohtml(x::QuoteNode, level::Int=0) =
  if isa(x.value, Symbol)
    (tags[:keyword], string(":", tohtml(x.value)))
  # this branch should never activate, really
  else
    string(":(",tohtml(x.value),")")
  end
tohtml(s::Symbol, level::Int=0) = (tags[:variable], string(s))

tohtml(t::Tuple, level::Int=0) =
  (tags[:tuple],
    (tags[:paren], "("),
    interpose((tags[:comma], ","), " ",
              map(x -> tohtml(x), t))...,
    (tags[:paren], ")"))

tohtml(t::Array, level::Int=0) =
  (tags[:vect],
    (tags[:paren], "["),
    interpose((tags[:comma], ","), " ",
              map(x -> tohtml(x), t))...,
    (tags[:paren], "]"))

tohtml(t::Dict, level::Int=0) =
  (tags[:dict],
   "Dict(\n",
   @rawindent(1),
   interpose((tags[:comma], ","),
              string("\n", @rawindent(1)),
              map(x -> tohtml(x, level+1), t))..., ")")
   
function tohtml(ex::Expr, level::Int=0)
  # special atoms
  if ex.head == ://
    (tags[:rational], string(ex.args[1], "//", ex.args[2]))
  elseif ex.head == :(=>)
    (tags[:pair],
      tohtml(ex.args[1]), " ",
      (tags[:opmisc], "=>"), " ",
      tohtml(ex.args[2]))

  # Collections
  elseif ex.head == :tuple || ex.head == :vect
    (tags[ex.head],
      (tags[:paren], "("),
      interpose((tags[:comma], ","), " ",
                map(x -> tohtml(x), ex.args))...,
      (tags[:paren], ")"))

  elseif ex.head == :call && ex.args[1] == :Dict
    (tags[:dict],
     "Dict", (tags[:paren], "("), "\n",
     @rawindent(1),
     interpose((tags[:comma], ","),
                string("\n", @rawindent(1)),
                map(x -> tohtml(x, level+1), ex.args[2:end]))...,
     (tags[:paren], ")"))
  
  # Macro forms
  # head :macro is taken care of with :function since it's the same.
  elseif ex.head == :quote
    if isa(ex.args[1], Symbol)
      (tags[:keyword], ":", tohtml(ex.args[1]))
    else
      (tags[:quote], ":",
        (tags[:paren], "("),
        interpose("\n",@rawindent(1), map(x->tohtml(x,level+1), ex.args)),
        (tags[:paren], ")"))
    end

  elseif ex.head == :$
    if isa(ex.args[1], Symbol)
      (tags[:unquote], string("\$", tohtml(ex.args[1])))
    else
      (tags[:unquote], "\$",
        (tags[:paren], "("), tohtml(ex.args[1]), (tags[:paren], ")"))
    end

  elseif ex.head == :...
    string(tohtml(ex.args[1]), (tags[:opmisc], "..."))

  elseif ex.head == :block
    if length(ex.args) == 1
      tohtml(ex.args[1], level)
    else
      (tags[:block],
        (tags[:reserved], "begin\n"),
        @rawindent(1),
        interpose("\n", @rawindent(1), map(x -> tohtml(x, level+1), ex.args))...,
        "\n",
        @rawindent(0),
        (tags[:reserved], "end"))
    end
  
  elseif ex.head == :call || ex.head == :macrocall
    ("span.call",
      tohtml(ex.args[1], level),
      (tags[:paren], "("),
      interpose((tags[:comma], ","), " ", map(tohtml, ex.args[2:end]))...,
      (tags[:paren], ")"))
         
  else
   "ERROR: could not htmlize $ex :ERROR"
  end
end

end
