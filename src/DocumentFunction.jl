__precompile__()

"""
DocumentFunction

https://github.com/madsjulia

Licensing: GPLv3: http://www.gnu.org/licenses/gpl-3.0.html
"""
module DocumentFunction

export documentfunction, getfunctionmethods, getfunctionarguments, getfunctionkeywords

"""
Get function methods

Arguments:

- `f`: function to be documented

Return:

- array with function methods
"""
function getfunctionmethods(f::Function)
	m = methods(f)
	return unique(sort(string.(m.ms)))
end

function documentfunction(f::Function; location::Bool=true, maintext::AbstractString="", argtext::Dict=Dict(), keytext::Dict=Dict())
	modulename = first(methods(f)).module
	sprint() do io
		if maintext != ""
			println(io, "**", parentmodule(f), ".", nameof(f), "**\n")
			println(io, "$(maintext)\n")
		end
		ms = getfunctionmethods(f)
		nm = length(ms)
		if nm == 0
			println(io, "No methods\n")
		else
			println(io, "Methods:")
			for i = 1:nm
				if contains(ms[i], " at ")
					s = strip.(split(ms[i], " at "))
					ss = strip.(split(s[1], " in "))
					methodname = ss[1]
					loc = s[2]
				else
					s = strip.(split(ms[i], " @ "))
					ss = strip.(split(s[2], " "))
					methodname = s[1]
					loc = ss[2]
				end
				if location
					println(io, " - `$modulename.$(methodname)` : `$(loc)`")
				else
					println(io, " - `$modulename.$(methodname)`")
				end
			end
			a = getfunctionarguments(ms)
			l = length(a)
			if l > 0
				println(io, "Arguments:")
				for i = 1:l
					arg = strip(string(a[i]))
					if occursin("::", arg)
						arg = first(split(arg, "::"))
					end
					if haskey(argtext, arg)
						at = argtext[arg]
						at = uppercasefirst(replace(at, "_"=>" "))
					else
						at = uppercasefirst(replace(arg, "_"=>" "))
					end
					println(io, " - `$(arg)` : $(at)")
				end
			end
			a = getfunctionkeywords(ms)
			l = length(a)
			if l > 0
				println(io, "Keywords:")
				for i = 1:l
					key = strip(string(a[i]))
					if haskey(keytext, key)
						kt = keytext[key]
						kt = uppercasefirst(replace(kt, "_"=>" "))
					else
						kt = uppercasefirst(replace(key, "_"=>" "))
					end
					println(io, " - `$(key)` : $(kt)")
				end
			end
		end
	end
end

function get_method_from_name(m::Module, f::Function)
	f = getfield(m, Symbol(f))
	ms = first(collect(methods(f)))
	args = Base.method_argnames(ms)
	kwargs = Base.kwarg_decl(ms)
	if any(kwargs .== Symbol("kw..."))
		kwargs = kwargs[1:end-1]
	end

	return Dict{Symbol, Any}(
		:name => f,
		:method => ms,
		:args => args[2:end],
		:kwargs => kwargs
	)
end

@doc """
Create function documentation

Arguments:

- `f`: function to be documented

Keywords:

- `maintext`: function description
- `argtext`: dictionary with text for each argument
- `keytext`: dictionary with text for each keyword
- `location`: show/hide function location on the disk
""" documentfunction

function getfunctionarguments(f::Function)
	getfunctionarguments(getfunctionmethods(f))
end
function getfunctionarguments(m::AbstractVector{String})
	mp = Array{String}(undef, 0)
	for i in eachindex(m)
		r = match(r"(.*)\(([^;]*);(.*)\)", m[i])
		if typeof(r) == Nothing
			r = match(r"(.*)\((.*)\)", m[i])
		end
		if typeof(r) != Nothing && length(r.captures) > 1
			s = split(r.captures[2], r"(?![^)(]*\([^)(]*?\)\)),(?![^\{]*\})")
			fargs = strip.(s)
			for j in 1:length(fargs)
				if !occursin("...", string(fargs[j])) && fargs[j] != ""
					push!(mp, fargs[j])
				end
			end
		end
	end
	return unique(mp)
end

@doc """
Get function arguments

Arguments:

- `f`: function to be documented"
- `m`: function methods
""" getfunctionarguments

function getfunctionkeywords(f::Function)
	getfunctionkeywords(getfunctionmethods(f))
end
function getfunctionkeywords(m::AbstractVector{String})
	mp = Array{String}(undef, 0)
	for i in eachindex(m)
		r = match(r"(.*)\(([^;]*);(.*)\)", m[i])
		if typeof(r) != Nothing && length(r.captures) > 2
			s = split(r.captures[3], r"(?![^)(]*\([^)(]*?\)\)),(?![^\{]*\})")
			kwargs = strip.(s)
			for j in 1:length(kwargs)
				if !occursin("...", string(kwargs[j])) && kwargs[j] != ""
					push!(mp, kwargs[j])
				end
			end
		end
	end
	return unique(mp)
end

@doc """
Get function keywords

Arguments:

- `f`: function to be documented
- `m`: function methods
""" getfunctionkeywords

end
