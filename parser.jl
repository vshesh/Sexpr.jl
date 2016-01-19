"""
#Parser
This module contains functions to take a string program and output the
AST form list that will be translated by the reader.

There are two steps of the s-expr -> julia translation happening here.

## tokenizing
This just splits up all the symbols/strings/special characters
and returns a list of them. For example:

```julia
tokenize("(+ 1 2)")
-> (AbstractString["(", "+", "1", "2", ")"], ((1,1),(1,2),(1,4),(1,6),(1,7)))
```
The two things that are returned are the list of tokens, and another list of
meta-information (right now it's just line/col number) for each of the tokens.
The line/colno is important to provide actual error reporting that someone
could use to debug their program. Otherwise it's no better than saying
"segfault".

## parsing
Parsing takes the list of tokens and returns an AST.
Since we're dealing with s-expressions, the AST is very basic, it just looks
like an in program representation of the list form of the program passed in.
example:

```julia
parse(tokenize("(+ 1 2)"))
-> (Any["+", "1", "2"], Any[(1,2),(1,4),(1,6)])
```
One interesting thing is that the meta-information (line/colno) for the
tokens that start forms, like quote, or open-paren, etc, are dropped.
There is another option which is to do something like
`((1,1), ((1,2), (1,4), (1,6)))` which is a two-element array containing the
parent form position, and then the positions of the contained forms. However,
doing it this way makes it more confusing to parse, since the two structures
now no longer reflect each other, and we end up with a mix-structure (atoms
have only one tuple, and the containing forms have a tuple of 2 tuples).
To avoid that mess, I'm keeping it simple like this.

As it is, checking paren matching is already done as part of the parsing step,
so the `Reader` module doesn't have to worry about it.

"""
module Parser

using Iterators
include("errors.jl")
using .Errors

export parsesexp
export VECID, DICTID

"""
preprocessor function, takes a string and strips comments.
The only error checking here is to make sure that quotes are closed.
This step simplifies the actual reading portion and allows it to only have to
deal with unclosed/matching parens.

multiline strings are allowed, and there's no padding subtraction.

there is also a list of line/colno passed along with the word.
This also greatly simplifies the reader, since it doesn't have to compute
or manually track this information for error reporting. It can just
"""
function tokenize(str::AbstractString)
  tokens = AbstractString[]
  places = Tuple{Int64, Int64}[]

  function endword()
    if length(word) > 0
      push!(tokens, word)
      push!(places, (lineno, colno-length(word)))
      word = ""
    end
  end

  in_str = false
  in_comment = false
  lineno = 1
  colno = 1
  word = ""

  for i in 1:length(str)
    c = str[i]

    # string mode state machine. amazingly, this one if case
    # takes care of all string stuff.
    if !in_comment && c == '"' && (i==1 || str[i-1] != '\\')
      in_str = !in_str
      if !in_str
        word = string(word, c)
      end
      # if we've started or ended a string, then add that token to the tokens
      # list.
      endword()
      # don't want to execute symbol reading portion if we're ending a string.
      if !in_str
        continue
      end
    end

    # comment mode state machine. The comments are completely ignored.
    if !in_str && c == ';'
      in_comment = true
    end
    if in_comment && c == '\n'
      in_comment = false
    end

    if !in_comment && !in_str
      if ismatch(r"[\s,]", string(c))
        # ignore whitespace and commas,
        # but also recognize them as word boundaries
        endword()
        continue
      end

      if c in ('[', ']', '(', ')', '{', '}', '\\')
        # parens are also word boundaries.
        # \\ begins a new character.
        # this is by no means an efficient state machine.
        endword()
      end
      # ^ metadata forms are not recognized as of now.
      # ^ maps to the exponentiation function instead.
      if word in ("[", "]", "(", ")", "{", "}", "'", "`") ||
        # ~ only counts if not followed by an @. (current character is the
        # one after word)
        (word == "~" && (i >= length(str) || str[i] != '@')) ||
        word == "~@"
        #these are all recognized tokens, so we should end the word and add it.
        endword()
      end
      word = string(word,c)
    end

    if !in_comment && in_str
      word = string(word, c)
    end

    # line/colno state machine.
    # this is independent of the rest of this function.
    # it has to come at the end, because the character c lines up with
    # lineno/colno as they already are, and they only change after the
    # processing is done.
    if c == '\n'
      lineno += 1
      colno = 1
    else
      colno += 1
    end
  end

  # basic context closing error checking
  if in_str
    throw(UnclosedError(lineno, colno, '"'))
  end

  # if length(word) > 0 here, then there is some form OUTSIDE the final
  # close paren that is just an atom, and we should drop that into the
  # sexpr too.
  endword()

  tokens, places
end


VECID = "::__vec__::"
DICTID = "::__dict__::"

function parseform(tokens, meta, state) # -> form, meta, state
  t,s = next(tokens, state)
  m = next(meta, state)[1]

  if t == ")"
    throw(ExtraError(m..., ')'))
  elseif t == "("
    parseparen(tokens, meta, s, ")")
  elseif t == "]"
    throw(ExtraError(m..., ']'))
  elseif t == "["
    parseparen(tokens, meta, s, "]")
  elseif t == "}"
    throw(ExtraError(m..., '}'))
  elseif t == "{"
    parseparen(tokens, meta, s, "}")

  elseif t in ("'", "`", "~", "~@")
    nf, nmf, ns = parseform(tokens, meta, s)
    Any[t, nf], Any[m, nmf], ns
  else
    # it's an atom.
    t,m,s
  end
end


function parseparen(tokens, meta, state, close) # -> form, meta, state
  if done(tokens, state)
    throw(UnclosedError(meta[state-1]..., close[1]))
  end

  p = []
  pm = []
  invalidclose = setdiff(Set{AbstractString}([")","]","}"]), Set([close]))

  if close == "]"
    push!(p, VECID)
    push!(pm, meta[state-1])
  elseif close == "}"
    push!(p, DICTID)
    push!(pm, meta[state-1])
  end

  s = state
  while !done(tokens, s) && next(tokens,s)[1] != close
    # if we find a different closing paren before the one we expect, it's a
    # mismatch.
    if next(tokens,s)[1] in invalidclose
      throw(MismatchedError(next(meta,s)[1]..., close[1], next(tokens,s)[1][1]))
    end

    f, mf, nextstate = parseform(tokens, meta, s)
    push!(p, f)
    push!(pm, mf)
    s = nextstate
  end
  if done(tokens, s) # we never found a matching closing paren.
    throw(UnclosedError(next(meta, state)[1]..., close[1]))
  end
  p, pm, next(tokens,s)[2]
end

function parsesexp(str, withmeta=true)
  tokens,meta = tokenize(str)
  s = start(tokens)
  forms = []
  metaforms = []
  while !done(tokens, s)
    f, mf, s = parseform(tokens, meta, s)
    push!(forms, f)
    push!(metaforms, mf)
  end
  if withmeta
    forms, metaforms
  else
    forms
  end
end

end #module

# if length(ARGS) > 0 && (ARGS[1] == "--run" || ARGS[1] == "-r")
#   eval(:(using .Parser))
#   println(parsesexp(readall(STDIN)))
# end
