DocumentFunction
================

A module for documenting Julia functions.

It provides methods to document function methods, arguments, and keywords.

<!-- [![Build Status](https://travis-ci.org/madsjulia/DocumentFunction.jl.svg?branch=master)](https://travis-ci.org/madsjulia/DocumentFunction.jl) -->
[![Coverage Status](https://coveralls.io/repos/madsjulia/DocumentFunction.jl/badge.svg?branch=master)](https://coveralls.io/r/madsjulia/DocumentFunction.jl?branch=master)

Installation:
------------

```julia
import Pkg; Pkg.add("DocumentFunction")

using DocumentFunction
```

Examples:
------------

``` julia
julia> print(documentfunction(documentfunction))

Methods:
 - `DocumentFunction.documentfunction(f::Function; location, maintext, argtext, keytext) in DocumentFunction` : /Users/monty/.julia/dev/DocumentFunction/src/DocumentFunction.jl:56
Arguments:
 - `f::Function`
Keywords:
 - `argtext`
 - `keytext`
 - `location`
 - `maintext`
```

``` julia
julia> print(documentfunction(occursin))

Methods:
 - `Base.occursin(delim::UInt8, buf::Base.GenericIOBuffer{Array{UInt8,1}}) in Base` : iobuffer.jl:464
 - `Base.occursin(delim::UInt8, buf::Base.GenericIOBuffer) in Base` : iobuffer.jl:470
 - `Base.occursin(needle::Union{AbstractChar, AbstractString}, haystack::AbstractString) in Base` : strings/search.jl:452
 - `Base.occursin(r::Regex, s::SubString; offset) in Base` : regex.jl:172
 - `Base.occursin(r::Regex, s::AbstractString; offset) in Base` : regex.jl:166
 - `Base.occursin(pattern::Tuple, r::Test.LogRecord) in Test` : /Users/osx/buildbot/slave/package_osx64/build/usr/share/julia/stdlib/v1.1/Test/src/logging.jl:211
Arguments:
 - `buf::Base.GenericIOBuffer`
 - `buf::Base.GenericIOBuffer{Array{UInt8,1}}`
 - `delim::UInt8`
 - `haystack::AbstractString`
 - `needle::Union{AbstractChar, AbstractString}`
 - `pattern::Tuple`
 - `r::Regex`
 - `r::Test.LogRecord`
 - `s::AbstractString`
 - `s::SubString`
Keywords:
 - `offset`
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
                 "m"=>"Input string array ...")))
    keytext=Dict("key1"=>"Key 1 ...",
                 "key2"=>"Key 2 ...")))                 
""" foobar
```

To get help for this new function, type `?foobar`.

This will produce the following output:

```
  foobar

  Foobar function to do amazing stuff!

  Methods:

    •    Main.foobar(f::Function) in Main

    •    Main.foobar(f::Function, m::Array{String,1}) in Main

  Arguments:

    •    f::Function : Input function ...

    •    m::Array{String,1} : Input string array ...
    
  Keywords:

    •    key1 : Key 1 ...

    •    key2 : Key 2 ...    

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

