DocumentFunction
================

[![DocumentFunction](http://pkg.julialang.org/badges/DocumentFunction_0.5.svg)](http://pkg.julialang.org/?pkg=DocumentFunction&ver=0.5)
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

MADS
====

[MADS](http://madsjulia.github.io/Mads.jl) (Model Analysis & Decision Support) is an integrated open-source high-performance computational (HPC) framework in [Julia](http://julialang.org).
MADS can execute a wide range of data- and model-based analyses:

* Sensitivity Analysis
* Parameter Estimation
* Model Inversion and Calibration
* Uncertainty Quantification
* Model Selection and Model Averaging
* Model Reduction and Surrogate Modeling
* Machine Learning and Blind Source Separation
* Decision Analysis and Support

MADS has been tested to perform HPC simulations on a wide-range multi-processor clusters and parallel enviromentls (Moab, Slurm, etc.).
MADS utilizes adaptive rules and techniques which allows the analyses to be performed with a minimum user input.
The code provides a series of alternative algorithms to execute each type of data- and model-based analyses.

Documentation
=============

All the available MADS modules and functions are described at [madsjulia.github.io](http://madsjulia.github.io/Mads.jl)

Installation
============

After starting Julia, execute:

```julia
Pkg.add("Mads")
```

Installation of MADS behind a firewall
------------------------------

Julia uses git for package management. Add in the `.gitconfig` file in your home directory:

```git
[url "https://"]
        insteadOf = git://
```

or execute:

```bash
git config --global url."https://".insteadOf git://
```

Set proxies:

```bash
export ftp_proxy=http://proxyout.<your_site>:8080
export rsync_proxy=http://proxyout.<your_site>:8080
export http_proxy=http://proxyout.<your_site>:8080
export https_proxy=http://proxyout.<your_site>:8080
export no_proxy=.<your_site>
```

For example, if you are doing this at LANL, you will need to execute the
following lines in your bash command-line environment:

```bash
export ftp_proxy=http://proxyout.lanl.gov:8080
export rsync_proxy=http://proxyout.lanl.gov:8080
export http_proxy=http://proxyout.lanl.gov:8080
export https_proxy=http://proxyout.lanl.gov:8080
export no_proxy=.lanl.gov
```

MADS examples
=============

In Julia REPL, do the following commands:

```julia
import Mads
```

To explore getting-started instructions, execute:

```julia
Mads.help()
```

There are various examples located in the `examples` directory of the `Mads` repository.

For example, execute

```julia
include(Mads.madsdir * "/../examples/contamination/contamination.jl")
```

to perform various example analyses related to groundwater contaminant transport, or execute

```julia
include(Mads.madsdir * "/../examples/bigdt/bigdt.jl")
```

to perform Bayesian Information Gap Decision Theory (BIG-DT) analysis.