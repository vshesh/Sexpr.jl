#!/usr/bin/env julia

# File: main.jl
# Author: Vishesh Gupta
# Created: 20 March 2016
#
# This is the file that contains the tool that is run on the command line.

using ArgParse
include("transpiler.jl")
include("util.jl")

function getopts(args)
  s = ArgParseSettings()
  s.prog="s-julia"
  s.description="
    A program to port clojure-like s-expression syntax to and from
    julia. By default, this program takes clojure syntax and outputs
    the julia version. Use -i to flip direction."
  s.autofix_names = true


  @add_arg_table s begin
    "--invert", "-i"
      help = "take julia code and print out s-expression code"
      action = :store_true
    "--cat", "-c"
      help = "cat all the input from STDIN rather than read from file. Ignores all arguments to the program."
      action = :store_true
    "--lines", "-l"
      help = "how many blank lines should exist between top level forms, default 1"
      arg_type = Int64
      default = 1
    "--output", "-o"
      help = "where to write out files if there are multiple positional arguments to the file. If this is empty, and there are >1 argument, the program will throw an error."
      nargs = 1
      action = :store_arg
    "--extension", "-e"
      help = "add an extension that qualifies as a lisp file (can use multiple times). Defaults: clj, cljs, cl, lisp, wisp, hy."
      nargs = 1
      action = :append_arg
    # "--strip", "-x"
    #   help = "removes julia bells and whistles from the clj output. Only applicable in the inverse direction."
    "files"
      help = "If given one file and no output directory, will dump to stdout. If given a directory or multiple files, eg \"sjulia file1 dir file2\", an output directory must be specified with -o/--output where the files will go."
      nargs = '*'
      action = :store_arg
  end

  return parse_args(args, s, as_symbols=true)
end

isset(args, flag) = haskey(args, flag) &&
  if isa(args[flag], Bool) args[flag]
  elseif isa(args[flag], Union{Array, Tuple}) length(args[flag]) > 0
  else true
  end

processfile(transpile::Function, program::AbstractString, lines::Int = 1) =
  processfile(STDOUT, transpile, program, lines)
function processfile(io::IO,
                     transpile::Function,
                     program::AbstractString,
                     lines::Int = 1)
  for form in transpile(program)
    println(io, form)
    print(io, repeat("\n", lines))
  end
end

const DEBUG = false

function main()
  if length(ARGS) == 0
    getopts(["-h"])
  end
  
  # configure parsedargs
  parsedargs = getopts(ARGS)
  DEBUG && info(parsedargs)
  
  isflagset = flag -> isset(parsedargs, flag)

  transpile = Transpiler.transpile
  outext = ".jl"
  if isflagset(:invert)
    transpile = Transpiler.detranspile
    outext = ".clj"
  end
  DEBUG && info("invert: $(isflagset(:invert))")
  DEBUG && info("outext: $(outext)")
    
  process = (io, program) -> processfile(
    io, transpile, program, parsedargs[:lines])

  if isflagset(:cat) || length(parsedargs[:files]) == 0
    DEBUG && info("mode: cat - reading from STDIN")
    process(STDOUT, readall(STDIN))
  else
    if length(parsedargs[:files]) > 1 && !isflagset(:output)
      error("There must be an output directory to process multiple files.")
    
    elseif length(parsedargs[:files]) == 1 &&
      isfile(parsedargs[:files][1]) &&
      !isflagset(:output)
      DEBUG && info("mode: single file STDOUT")
      # it's okay to have only 1 file - if no output,then dump to STDOUT
      process(STDOUT, readall(parsedargs[:files][1]))
    else
      DEBUG && info("mode: files to output directory $(parsedargs[:output][1])")
      # have nonzero files and output is set.
      # output is the head of the path where to write the file
      for path in parsedargs[:files]
        if isfile(path)
          outfile = open(joinpath(parsedargs[:output][1],
                             string(splitext(basename(path))[1], ".jl")), "w")
          process(outfile, readall(path))
          close(outfile)
        elseif isdir(path)
          # filter extensions? (-e option to set extensions)
          #
          for file in Task(() -> Util.finddir(path))
            outfile = open(joinpath(parsedargs[:output][1],
                               file[length(path)+1:end]), "w")
            info("writing $outfile")
            process(outfile, readall(file))
            close(outfile)
          end
        end
      end
    end
  end
end

main()
