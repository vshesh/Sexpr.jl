module Errors

export ExtraError, MismatchedError, UnclosedError
export InvalidTokenError, InvalidFormCountError, WrappedException

"""
Reader error types.
"""
type ExtraError <: Exception
  lineno::Int
  colno::Int
  c::Char
end
Base.showerror(io::IO, e::ExtraError) =
  print(io, "$(typeof(e)) at line $(e.lineno):$(e.colno), extra $(e.c) found.")

type MismatchedError <: Exception
  lineno::Int
  colno::Int
  expected::Char
  found::Char
end
Base.showerror(io::IO, e::MismatchedError) =
  print(io, "$(typeof(e)) at line $(e.lineno):$(e.colno) found mismatch, ",
        "expected $(e.expected), found $(e.found) instead")

type UnclosedError <: Exception
  lineno::Int
  colno::Int
  c::Char
end
Base.showerror(io::IO, e::UnclosedError) =
  print(io,
        "$(typeof(e)): missing closing $(e.c) ",
        "from form starting at line $(e.lineno):$(e.colno)")

# If someone types garbage as a symbol, this error will come up.
type InvalidTokenError <: Exception
  lineno::Int
  colno::Int
  token::AbstractString
end
Base.showerror(io::IO, e::InvalidTokenError) =
  print(io, "$(typeof(e)) at line $(e.lineno):$(e.colno), ",
        "invalid token found: $(e.token)")

type InvalidFormCountError <: Exception
  lineno::Int
  colno::Int
  kind::AbstractString
  form::AbstractString
  expected::AbstractString
  found::AbstractString
end
Base.showerror(io::IO, e::InvalidFormCountError) =
  print(io,
        "At line $(lineno):$(colno), $(e.kind) should have ",
        "$(e.expected) forms, ",
        "found $(e.found) instead: $(e.form)")

type WrappedException <: Exception
  lineno::Int
  colno::Int
  e::Exception
  message::AbstractString
end
Base.showerror(io::IO, e::WrappedException) =
  print(io, "$(typeof(e)) at line $(lineno):$(colno): $(e.message)")

end
