__precompile__()

"""
DocumentFunction

https://github.com/madsjulia/DocumentFunction.jl
"""
module DocumentFunction

export DescriptionDraft,
	DocPatch,
	DocumentationDraft,
	DocumentationIssue,
	ExampleDraft,
	ExampleVerification,
	FunctionSpec,
	KeywordParameter,
	MethodSpec,
	ParameterKind,
	ParameterSpec,
	PositionalParameter,
	SourceSpan,
	applypatch!,
	checkdocs,
	docpatch,
	documentationcontext,
	documentfunction,
	draftdocumentation,
	exampledraft,
	formatissues,
	functionspec,
	getfunctionarguments,
	getfunctionkeywords,
	getfunctionmethods,
	needsreview,
	renderdocumentation,
	renderdocstring,
	scan,
	scanfunctions,
	verifyexample,
	verifyexamples,
	writeinventory

include("types.jl")
include("source_scan.jl")
include("drafting.jl")
include("example_verification.jl")
include("rendering.jl")
include("context.jl")
include("checking.jl")

_METHOD_SELF_NAME = Symbol("#self#")

function _method_argnames_no_self(m::Method)
	argnames = Base.method_argnames(m)
	if !isempty(argnames) && argnames[1] == _METHOD_SELF_NAME
		return argnames[2:end]
	end
	return argnames
end

function _method_kwarg_names(m::Method)
	kwargs = Base.kwarg_decl(m)
	# Julia uses `kw...` to indicate keyword varargs; exclude it.
	if any(kwargs .== Symbol("kw..."))
		kwargs = kwargs[1:end-1]
	end
	return kwargs
end

function _is_vararg_signature(m::Method)
	sig = Base.unwrap_unionall(m.sig)
	params = sig.parameters
	return !isempty(params) && Base.isvarargtype(params[end])
end

function _type_string(t)
	# Match `string`-based display used by Julia signatures reasonably well.
	# If Julia ever changes the internal representation, we fall back to `string(t)`.
	try
		return sprint(show, t)
	catch
		return string(t)
	end
end

function _getfunctionarguments(methods_vec::AbstractVector{Method})
	args = String[]
	for m in methods_vec
		argnames = _method_argnames_no_self(m)
		if isempty(argnames)
			continue
		end
		sig = Base.unwrap_unionall(m.sig)
		# `sig.parameters` includes the function type as the first parameter.
		# Remaining parameters correspond to positional arguments.
		argtypes = sig.parameters[2:end]

		is_vararg = _is_vararg_signature(m)
		for (i, a) in enumerate(argnames)
			# Legacy behavior: do not list varargs ("...")
			if is_vararg && i == length(argnames)
				continue
			end
			argname = string(a)
			argtype = i <= length(argtypes) ? _type_string(argtypes[i]) : "Any"
			push!(args, "$(argname)::$(argtype)")
		end
	end
	return unique(args)
end

function _getfunctionkeywords(methods_vec::AbstractVector{Method})
	keys = String[]
	for m in methods_vec
		for k in _method_kwarg_names(m)
			push!(keys, string(k))
		end
	end
	return unique(keys)
end

"""
    documentfunction(f::Function; location=true, maintext="", argtext=Dict(), keytext=Dict())

Render legacy Markdown describing the methods, positional arguments, and
keywords of `f`.

# Arguments

- `f`: Function whose runtime methods are inspected.

# Keywords

- `location`: Whether to include runtime-derived source locations in the Markdown.
- `maintext`: Optional prose shown before the method list.
- `argtext`: Descriptions keyed by exact positional-argument name strings.
- `keytext`: Descriptions keyed by exact keyword name strings.

# Returns

A newline-terminated Markdown string.

# Notes

This compatibility API uses runtime reflection and does not retain keyword
types, defaults, or requiredness; new documentation should use
[`scanfunctions`](@ref) and static docstrings.
"""
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
			a = getfunctionarguments(f)
			l = length(a)
			if l > 0
				println(io, "Arguments:")
				for i = 1:l
					arg = strip(string(a[i]))
					if occursin("::", arg)
						arg, arg_type = split(arg, "::")
					else
						arg_type = "Any"
					end
					if haskey(argtext, arg)
						at = argtext[arg]
						at = uppercasefirst(replace(at, "_"=>" "))
					else
						at = uppercasefirst(replace(arg, "_"=>" "))
					end
					println(io, " - `$(arg)` :: `$(arg_type)` : $(at)")
				end
			end
			a = getfunctionkeywords(f)
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

"""
    getfunctionmethods(f::Function)

Return sorted, unique rendered method strings for `f`.

# Arguments

- `f`: Function whose runtime method table is inspected.

# Returns

A vector of rendered method strings.
"""
function getfunctionmethods(f::Function)
	m = methods(f).ms
	return unique(sort(string.(m)))
end

# TODO currently not used but it works
# for example: DocumentFunction.getfunctionmethods2(DocumentFunction, DocumentFunction.getfunctionmethods)
function getfunctionmethods2(f::Function)
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

function getfunctionarguments(f::Function)
	return _getfunctionarguments(collect(methods(f)))
end
function getfunctionarguments(m::AbstractVector{String})
	mp = Array{String}(undef, 0)
	for i in eachindex(m)
		r = match(r"(.*)\(([^;]*);(.*)\)", m[i])
		if isnothing(r)
			r = match(r"(.*)\((.*)\)", m[i])
		end
		if !isnothing(r) && length(r.captures) > 1
			s = split(r.captures[2], r"(?![^)(]*\([^)(]*?\)\)),(?![^\{]*\})")
			fargs = strip.(s)
			for j = eachindex(fargs)
				if !occursin("...", string(fargs[j])) && fargs[j] != ""
					push!(mp, fargs[j])
				end
			end
		end
	end
	return unique(mp)
end
@doc """
    getfunctionarguments(f::Function)
    getfunctionarguments(method_strings::AbstractVector{String})

Return unique legacy positional-argument fragments.

# Arguments

- `f`: Function whose runtime methods are inspected with Julia reflection.
- `m`: Rendered method strings to parse on a best-effort basis.

# Returns

A vector of argument strings in first-seen order.

# Notes

The function overload omits positional varargs and does not preserve defaults.
The string overload is a compatibility parser, not a complete Julia syntax
parser; use [`scanfunctions`](@ref) for source-faithful metadata.
""" getfunctionarguments

function getfunctionkeywords(f::Function)
	return _getfunctionkeywords(collect(methods(f)))
end
function getfunctionkeywords(m::AbstractVector{String})
	mp = Array{String}(undef, 0)
	for i in eachindex(m)
		r = match(r"(.*)\(([^;]*);(.*)\)", m[i])
		if !isnothing(r)  && length(r.captures) > 2
			s = split(r.captures[3], r"(?![^)(]*\([^)(]*?\)\)),(?![^\{]*\})")
			kwargs = strip.(s)
			for j = eachindex(kwargs)
				if !occursin("...", string(kwargs[j])) && kwargs[j] != ""
					push!(mp, kwargs[j])
				end
			end
		end
	end
	return unique(mp)
end
@doc """
    getfunctionkeywords(f::Function)
    getfunctionkeywords(method_strings::AbstractVector{String})

Return unique legacy keyword names or fragments.

# Arguments

- `f`: Function whose runtime methods are inspected with Julia reflection.
- `m`: Rendered method strings to parse on a best-effort basis.

# Returns

A vector of keyword strings in first-seen order.

# Notes

The function overload discards keyword types, defaults, and requiredness.
The string overload may retain raw annotations or defaults and is not a
complete Julia syntax parser; use [`scanfunctions`](@ref) for source-faithful
metadata.
""" getfunctionkeywords

end
