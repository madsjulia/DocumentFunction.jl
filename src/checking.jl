import TOML

function _project_directory(path::AbstractString)::String
	candidate::String = isdir(path) ? abspath(path) : dirname(abspath(path))
	while true
		if isfile(joinpath(candidate, "Project.toml"))
			return candidate
		end
		parent::String = dirname(candidate)
		if parent == candidate
			return isdir(path) ? abspath(path) : dirname(abspath(path))
		end
		candidate = parent
	end
end

function _default_state_path(path::AbstractString)::String
	return joinpath(_project_directory(path), ".documentfunction.toml")
end

function _parameter_documented(existing::Dict{Symbol, String}, parameter::ParameterSpec)::Bool
	if parameter.anonymous
		return true
	end
	return haskey(existing, parameter.name) && !isempty(strip(existing[parameter.name]))
end

"""
    checkdocs(path; public_only=true, require_parameters=false, state_path="", module_name="")

Return deterministic, offline documentation issues for scanned functions.

When `.documentfunction.toml` exists, source hashes accepted by a previous
review are also checked so changed implementations are reported as stale.

# Arguments

- `path`: Julia source file or directory to inspect.

# Keywords

- `public_only`: Whether to check only exported, declared-public, or explicitly documented functions.
- `require_parameters`: Whether every extracted argument and keyword must have a structured description.
- `state_path`: Documentation inventory path, or an empty string to use the project default.
- `module_name`: Module prefix to use instead of the nearest project name.

# Returns

A vector of `DocumentationIssue` records in deterministic source order.
"""
function checkdocs(
	path::AbstractString;
	public_only::Bool=true,
	require_parameters::Bool=false,
	state_path::AbstractString="",
	module_name::AbstractString="",
)::Vector{DocumentationIssue}
	functions::Vector{FunctionSpec} = scanfunctions(path; public_only=public_only, module_name=module_name)
	issues::Vector{DocumentationIssue} = DocumentationIssue[]
	resolved_state_path::String = isempty(state_path) ? _default_state_path(path) : abspath(state_path)
	state_exists::Bool = isfile(resolved_state_path)
	state::Dict{String, Any} = state_exists ? TOML.parsefile(resolved_state_path) : Dict{String, Any}()
	tracked::AbstractDict = get(state, "functions", Dict{String, Any}())

	for spec::FunctionSpec in functions
		source::Union{Nothing, SourceSpan} = isempty(spec.methods) ? nothing : first(spec.methods).source
		if isnothing(spec.existing_doc)
			push!(issues, DocumentationIssue(
				:missing,
				spec.qualified_name,
				"No attached static documentation was found.",
				source,
			))
		elseif occursin("TODO:", spec.existing_doc)
			push!(issues, DocumentationIssue(
				:incomplete,
				spec.qualified_name,
				"Attached documentation contains an unresolved TODO.",
				spec.doc_span,
			))
		end

		if require_parameters && !isnothing(spec.existing_doc)
			existing::Dict{Symbol, String} = _existing_parameter_text(spec.existing_doc)
			for kind::ParameterKind in (PositionalParameter, KeywordParameter)
				for parameter::ParameterSpec in _unique_parameters(spec, kind)
					if !_parameter_documented(existing, parameter)
						push!(issues, DocumentationIssue(
							:incomplete,
							spec.qualified_name,
							"Parameter `$(parameter.name)` has no structured description.",
							spec.doc_span,
						))
					end
				end
			end
		end

		if state_exists
			if !haskey(tracked, spec.qualified_name)
				push!(issues, DocumentationIssue(
					:untracked,
					spec.qualified_name,
					"The function has not been accepted into the documentation inventory.",
					source,
				))
			else
				entry::AbstractDict = tracked[spec.qualified_name]
				accepted_hash::String = String(get(entry, "source_hash", ""))
				if accepted_hash != spec.source_hash
					push!(issues, DocumentationIssue(
						:stale,
						spec.qualified_name,
						"The implementation changed after its documentation was last accepted.",
						source,
					))
				end
			end
		end
	end
	return issues
end

"""
    writeinventory(path; output="", public_only=true, allow_incomplete=false, module_name="")

Write a deterministic TOML inventory of reviewed source hashes.

Run this only after reviewing generated prose and verifying applicable
examples; CI can subsequently use [`checkdocs`](@ref) without AI or network
access.

# Arguments

- `path`: Julia source file or directory whose accepted hashes should be recorded.

# Keywords

- `output`: Inventory destination, or an empty string to use `.documentfunction.toml` in the project root.
- `public_only`: Whether to inventory only exported, declared-public, or explicitly documented functions.
- `allow_incomplete`: Whether to record functions with missing documentation or unresolved `TODO` markers.
- `module_name`: Module prefix to use instead of the nearest project name.

# Returns

The absolute path of the written inventory file.
"""
function writeinventory(
	path::AbstractString;
	output::AbstractString="",
	public_only::Bool=true,
	allow_incomplete::Bool=false,
	module_name::AbstractString="",
)::String
	functions::Vector{FunctionSpec} = scanfunctions(path; public_only=public_only, module_name=module_name)
	if !allow_incomplete
		incomplete::Vector{String} = [
			spec.qualified_name
			for spec::FunctionSpec in functions
			if isnothing(spec.existing_doc) || occursin("TODO:", spec.existing_doc)
		]
		if !isempty(incomplete)
			throw(ArgumentError("refusing to accept incomplete documentation for: $(join(incomplete, ", "))"))
		end
	end
	entries::Dict{String, Any} = Dict{String, Any}()
	for spec::FunctionSpec in sort(functions; by=_function_name)
		entries[spec.qualified_name] = Dict{String, Any}(
			"documented" => !isnothing(spec.existing_doc),
			"source_hash" => spec.source_hash,
		)
	end
	state::Dict{String, Any} = Dict{String, Any}(
		"format" => 1,
		"functions" => entries,
	)
	output_path::String = isempty(output) ? _default_state_path(path) : abspath(output)
	temporary_path::String, temporary_io::IOStream = mktemp(dirname(output_path))
	TOML.print(temporary_io, state; sorted=true)
	close(temporary_io)
	mv(temporary_path, output_path; force=true)
	return output_path
end

function _function_name(spec::FunctionSpec)::String
	return spec.qualified_name
end

"""
    formatissues(issues; root="")

Format documentation issues without exposing absolute paths by default.

# Arguments

- `issues`: Documentation issues to format.

# Keywords

- `root`: Root used to render source locations as relative paths, or an empty string to show basenames.

# Returns

A newline-delimited diagnostic string.
"""
function formatissues(
	issues::AbstractVector{DocumentationIssue};
	root::AbstractString="",
)::String
	io::IOBuffer = IOBuffer()
	for issue::DocumentationIssue in issues
		location::String = if isnothing(issue.source)
			""
		else
			" $(_display_path(issue.source.path, root)):$(issue.source.first_line)"
		end
		println(io, "[$(issue.code)] $(issue.qualified_name)$(location): $(issue.message)")
	end
	return chomp(String(take!(io)))
end
