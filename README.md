DocumentFunction
================

Documenting Julia functions and their arguments and keywords.

<!-- [![Build Status](https://travis-ci.org/madsjulia/DocumentFunction.jl.svg?branch=master)](https://travis-ci.org/madsjulia/DocumentFunction.jl) -->
[![Coverage Status](https://coveralls.io/repos/madsjulia/DocumentFunction.jl/badge.svg?branch=master)](https://coveralls.io/r/madsjulia/DocumentFunction.jl?branch=master)

Installation:
------------

```julia
import Pkg; Pkg.add("DocumentFunction")

import DocumentFunction
```

Examples:
------------

``` julia
julia> print(DocumentFunction.documentfunction(DocumentFunction.documentfunction))

Methods:
 - `DocumentFunction.documentfunction(f::Function; location, maintext, argtext, keytext)` : `C:\Users\monty\.julia\dev\DocumentFunction\src\DocumentFunction.jl:26`
Arguments:
 - `f` :: `Function` : F
Keywords:
 - `location` : Location
 - `maintext` : Maintext
 - `argtext` : Argtext
 - `keytext` : Keytext
```

``` julia
julia> print(DocumentFunction.documentfunction(occursin))

Methods:
 - `Base.occursin(delim::UInt8, buf::Base.GenericIOBuffer)` : `iobuffer.jl:574`
 - `Base.occursin(delim::UInt8, buf::IOBuffer)` : `iobuffer.jl:568`
 - `Base.occursin(haystack)` : `strings\search.jl:724`
 - `Base.occursin(needle::Union{AbstractChar, AbstractString}, haystack::AbstractString)` : `strings\search.jl:699`
 - `Base.occursin(r::Regex, s::AbstractString; offset)` : `regex.jl:292`
 - `Base.occursin(r::Regex, s::SubString{String}; offset)` : `regex.jl:297`
Arguments:
 - `delim` :: `UInt8` : Delim
 - `buf` :: `Base.GenericIOBuffer` : Buf
 - `buf` :: `IOBuffer` : Buf
 - `haystack` :: `Any` : Haystack
 - `needle` :: `Union{AbstractChar, AbstractString}` : Needle
 - `haystack` :: `AbstractString` : Haystack
 - `r` :: `Regex` : R
 - `s` :: `AbstractString` : S
 - `s` :: `SubString{String}` : S
Keywords:
 - `offset` : Offset
```

Documentation Example:
---------

```julia
import DocumentFunction

function foobar(f::Function)
    return nothing
end
function foobar(f::Function, m::Vector{String}; key1::Bool, key2::String)
    return nothing
end
@doc """
$(DocumentFunction.documentfunction(foobar;
    location=false,
    maintext="Foobar function to do amazing stuff!",
    argtext=Dict("f"=>"Input function ...",
                 "m"=>"Input string array ..."),
    keytext=Dict("key1"=>"Key 1 ...",
                 "key2"=>"Key 2 ...")))
""" foobar
```

To get help for this new function, type `?foobar`.

This will produce the following output:

```
Main.foobar

  Foobar function to do amazing stuff!

  Methods:

    •  Main.foobar(f::Function)

    •  Main.foobar(f::Function, m::Vector{String}; key1, key2)

  Arguments:

    •  f :: Function : Input function ...

    •  m :: Vector{String} : Input string array ...

  Keywords:

    •  key1 : Key1

    •  key2 : Key2
```

Projects using DocumentFunction
-----------------

* [MADS](https://github.com/madsjulia) (function documentation is produced using DocumentFunction: [https://madsjulia.github.io/Mads.jl/Modules/Mads](https://madsjulia.github.io/Mads.jl/Modules/Mads))
* [SmartTensors](https://github.com/SmartTensors)

Projects:
---------

* [MADS](https://github.com/madsjulia)
* [SmartTensors](https://github.com/SmartTensors)
* [SmartML](https://github.com/SmartTensors/SmartML.jl)

Publications, Presentations
--------------------------

* [mads.gitlab.io](http://mads.gitlab.io)
* [madsjulia.github.io](https://madsjulia.github.io)
* [SmartTensors](https://SmartTensors.github.io)
* [SmartTensors.com](https://SmartTensors.com)
* [monty.gitlab.io](http://monty.gitlab.io)
* [montyv.github.io](https://montyv.github.io)