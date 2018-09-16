DocumentFunction
================

[![DocumentFunction](http://pkg.julialang.org/badges/DocumentFunction_0.5.svg)](http://pkg.julialang.org/?pkg=DocumentFunction&ver=0.5)
[![DocumentFunction](http://pkg.julialang.org/badges/DocumentFunction_0.6.svg)](http://pkg.julialang.org/?pkg=DocumentFunction&ver=0.6)
[![DocumentFunction](http://pkg.julialang.org/badges/DocumentFunction_0.7.svg)](http://pkg.julialang.org/?pkg=DocumentFunction&ver=0.7)
[![Build Status](https://travis-ci.org/madsjulia/DocumentFunction.jl.svg?branch=master)](https://travis-ci.org/madsjulia/DocumentFunction.jl)
[![Coverage Status](https://coveralls.io/repos/madsjulia/DocumentFunction.jl/badge.svg?branch=master)](https://coveralls.io/r/madsjulia/DocumentFunction.jl?branch=master)

DocumentFunction is a module of [MADS](https://github.com/madsjulia) (Model Analysis & Decision Support).

Installation:
------------

```julia
Pkg.add("DocumentFunction")
```

Example:
------------

```julia
import DocumentFunction

function getfunctionarguments(f::Function)
    m = methods(f)
    getfunctionarguments(f, string.(collect(m.ms)))
end
function getfunctionarguments(f::Function, m::Vector{String})
    l = length(m)
    mp = Array{Symbol}(0)
    for i in 1:l
        r = match(r"(.*)\(([^;]*);(.*)\)", m[i])
        if typeof(r) == Void
            r = match(r"(.*)\((.*)\)", m[i])
        end
        if typeof(r) != Void && length(r.captures) > 1
            fargs = strip.(split(r.captures[2], ", "))
            for j in 1:length(fargs)
                if !contains(string(fargs[j]), "...") && fargs[j] != ""
                    push!(mp, fargs[j])
                end
            end
        end
    end
    return sort(unique(mp))
end

@doc """
$(DocumentFunction.documentfunction(getfunctionarguments;
location=false,
maintext="Get function arguments",
argtext=Dict("f"=>"Function to be documented",
             "m"=>"Function methods")))
""" getfunctionarguments
```

Execution of

`?getfunctionarguments`

produces the following output:

```
  DocumentFunction.getfunctionarguments

  Get function arguments

  Methods

    •    DocumentFunction.getfunctionarguments(f::Function)

    •    DocumentFunction.getfunctionarguments(f::Function, m::Array{String,1})


  Arguments

    •    f::Function : Function to be documented

    •    m::Array{String,1} : Function methods

```

Developers
==========

* [Velimir (monty) Vesselinov](http://www.lanl.gov/orgs/ees/staff/monty) [(publications)](http://scholar.google.com/citations?user=sIFHVvwAAAAJ)
* [Daniel O'Malley](http://www.lanl.gov/expertise/profiles/view/daniel-o'malley) [(publications)](http://scholar.google.com/citations?user=rPzCVjEAAAAJ)
* [see also](https://github.com/madsjulia/DocumentFunction.jl/graphs/contributors)

Publications, Presentations, Projects
=====================================

* [mads.lanl.gov/](http://mads.lanl.gov/)
* [ees.lanl.gov/monty](http://ees.lanl.gov/monty)
