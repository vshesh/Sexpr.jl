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

"""
tostring(x::Any)
takes an ast node (basically, anything) and returns a string version
of it by using @sprintf (which will play nicely with anyone who overrides
show for their custom objects. There are no custom objects in the project
as of now, but if there ever have to be (thanks to hash dispatch) it might
be a good idea to support that).
"""
tostring(x, level::Int=0) = @indent @sprintf("%s", x)

tostring(x::Void, level::Int=0) = @indent "nil"
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
           if length(ex.args) > 2
             string("\n",
                    @indent("else\n"),
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
           tostring(ex.args[2], level+1), "\n",
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
           join(map(x->tostring(x,level+1), ex.args[3].args[3:end-1]), "\n\n"),
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

end
