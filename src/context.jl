function _display_path(path::AbstractString, root::AbstractString)::String
	if isempty(root)
		return basename(path)
	end
	return replace(relpath(path, abspath(root)), '\\' => '/')
end

function _evidence_files(paths::AbstractVector{<:AbstractString})::Vector{String}
	files::Vector{String} = String[]
	for path::AbstractString in paths
		if isfile(path)
			push!(files, abspath(path))
		elseif isdir(path)
			for (directory::String, subdirectories::Vector{String}, names::Vector{String}) in walkdir(abspath(path))
				sort!(subdirectories)
				for name::String in sort(names)
					if endswith(lowercase(name), ".jl") || endswith(lowercase(name), ".md")
						push!(files, joinpath(directory, name))
					end
				end
			end
		end
	end
	return unique(files)
end

function _callsite_lines(
	spec::FunctionSpec,
	paths::AbstractVector{<:AbstractString},
	root::AbstractString,
	maximum::Int,
)::Vector{String}
	result::Vector{String} = String[]
	binding_name::String = _last_binding_component(spec.qualified_name)
	needle::String = "$(binding_name)("
	for path::String in _evidence_files(paths)
		for (line_number::Int, line::SubString{String}) in enumerate(split(read(path, String), '\n'))
			if occursin(needle, line)
				push!(result, "$(_display_path(path, root)):$(line_number): $(strip(String(line)))")
				if length(result) >= maximum
					return result
				end
			end
		end
	end
	return result
end

function _parameter_context(io::IO, parameter::ParameterSpec, draft::DescriptionDraft)::Nothing
	println(io, "- `$(_parameter_label(parameter))`")
	println(io, "  - required: `$(parameter.required)`")
	println(io, "  - variadic: `$(parameter.variadic)`")
	println(io, "  - anonymous: `$(parameter.anonymous)`")
	println(io, "  - draft: $(draft.text)")
	println(io, "  - confidence: $(round(draft.confidence; digits=2))")
	println(io, "  - provenance: `$(draft.provenance)`")
	println(io, "  - evidence: $(draft.evidence)")
	return nothing
end

function _markdown_fence(content::AbstractString)::String
	longest_run::Int = 0
	for matched::RegexMatch in eachmatch(r"`+", String(content))
		longest_run = max(longest_run, length(matched.match))
	end
	return repeat("`", max(3, longest_run + 1))
end

"""
    documentationcontext(spec; root="", evidence_paths=String[], max_callsites=8)

Produce a deterministic evidence bundle for a human or coding agent to turn
into semantic Julia documentation.

The bundle includes source-defined signatures, defaults, candidate prose,
existing documentation, implementation text, and matching calls from supplied
test, example, or documentation paths.

# Arguments

- `spec`: Structured function metadata to describe.

# Keywords

- `root`: Repository root used to render relative evidence paths.
- `evidence_paths`: Test, example, or documentation files and directories to search for representative calls.
- `max_callsites`: Maximum number of matching call-site lines to include.

# Returns

A Markdown evidence bundle suitable for human or coding-agent review.
"""
function documentationcontext(
	spec::FunctionSpec;
	root::AbstractString="",
	evidence_paths::AbstractVector{<:AbstractString}=String[],
	max_callsites::Int=8,
)::String
	draft::DocumentationDraft = draftdocumentation(spec)
	io::IOBuffer = IOBuffer()
	println(io, "# Documentation evidence: `$(spec.qualified_name)`\n")
	println(io, "Source hash: `$(spec.source_hash)`")
	println(io, "Exported: `$(spec.is_exported)`")
	println(io, "Public: `$(spec.is_public)`\n")
	println(io, "## Signatures\n")
	for method::MethodSpec in spec.methods
		println(io, "- `$(method.signature)`")
	end

	arguments::Vector{ParameterSpec} = _unique_parameters(spec, PositionalParameter)
	if !isempty(arguments)
		println(io, "\n## Positional arguments\n")
		for parameter::ParameterSpec in arguments
			_parameter_context(io, parameter, draft.arguments[parameter.name])
		end
	end
	keywords::Vector{ParameterSpec} = _unique_parameters(spec, KeywordParameter)
	if !isempty(keywords)
		println(io, "\n## Keywords\n")
		for parameter::ParameterSpec in keywords
			_parameter_context(io, parameter, draft.keywords[parameter.name])
		end
	end

	if !isnothing(spec.existing_doc)
		println(io, "\n## Existing documentation\n")
		doc_fence::String = _markdown_fence(spec.existing_doc)
		println(io, "$(doc_fence)text")
		println(io, spec.existing_doc)
		println(io, doc_fence)
	end

	println(io, "\n## Implementations\n")
	for method::MethodSpec in spec.methods
		println(io, "### `$(_display_path(method.source.path, root)):$(method.source.first_line)`\n")
		implementation_fence::String = _markdown_fence(method.source_text)
		println(io, "$(implementation_fence)julia")
		println(io, method.source_text)
		println(io, "$(implementation_fence)\n")
	end

	callsites::Vector{String} = _callsite_lines(spec, evidence_paths, root, max_callsites)
	if !isempty(callsites)
		println(io, "## Calls found in tests, examples, or documentation\n")
		for callsite::String in callsites
			println(io, "- `$(callsite)`")
		end
	end

	println(io, "\n## Authoring requirements\n")
	println(io, "- Describe observable behavior from implementation, tests, examples, and call sites; do not rely on names alone.")
	println(io, "- Give every argument and keyword a behavioral description, including the effect of Boolean values and any established units or constraints.")
	println(io, "- Treat a `::Type` suffix as a declared return type, not an inferred guarantee.")
	println(io, "- Prefer an example adapted from passing tests and mark it as a `jldoctest` only after executing it.")
	println(io, "- Do not invent accepted values, domain meaning, side effects, array shapes, credentials, paths, or return behavior.")
	println(io, "- Return ordinary static Julia docstrings and identify unresolved claims explicitly.")
	return chomp(String(take!(io)))
end
