"""
Contains utilities that are useful for running tests in this project.
Presumably you could also write tests for the stuff in here, but I'll leave
that to another day.
"""
module TestUtil

using FactCheck

export testdir

function testdir(
  directory::AbstractString,
  istestfile::Function,
  test::Function,
  commentchar::Char=';')
  
  commentline = Regex("^\s*$commentchar")
  
  for filename in readdir(directory)
    if !istestfile(filename) continue end
    
    open(joinpath(directory, filename)) do f
      facts(readline(f)) do
        line = nothing
        while !eof(f)
          line = readline(f)
          if match(r"^\s*$", line) == nothing &&
             match(commentline, line) == nothing
            break
          end
        end
        while !eof(f)
          context(line) do
            while !eof(f)
              line = readline(f)
              if match(r"^\s*$", line) != nothing ||
                 match(commentline, line) != nothing
                continue
              end
              # break if we're on a context line
              if !contains(line, "|||") break end
              test(line)
            end
          end
        end
      end
    end
    print("\n\n")
    
  end
end


end