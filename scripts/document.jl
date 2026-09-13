import DocumentFunction

Base.@kwdef mutable struct Options
	mode::Symbol = :draft
	source::String = "src"
	output::String = ""
	module_name::String = ""
	function_name::String = ""
	public_only::Bool = true
	changed_only::Bool = false
	require_parameters::Bool = false
	max_callsites::Int = 8
end

function _usage()::String
	return """
Usage:
  julia --startup-file=no --project=. scripts/document.jl [mode] [options]

Modes:
  --draft       Render conservative offline documentation drafts (default).
  --missing     Render drafts only for undocumented functions.
  --prompt      Emit evidence bundles for Codex or another reviewer.
  --check       Fail on missing, incomplete, untracked, or stale documentation.
  --baseline    Accept current reviewed source hashes in .documentfunction.toml.

Options:
  --source=PATH             Source file or directory (default: src).
  --output=PATH             Write output to a file instead of stdout.
  --module=NAME             Override the inferred module name.
  --function=NAME           Select one qualified or unqualified function name.
  --changed                 Limit draft/prompt output to changed Julia files.
  --all                     Include non-public, undocumented functions.
  --require-parameters      Require structured parameter descriptions in --check.
  --max-callsites=N         Maximum evidence call sites per function.
"""
end

function _parse_options(arguments::Vector{String})::Options
	options::Options = Options()
	for argument::String in arguments
		if argument == "--draft"
			options.mode = :draft
		elseif argument == "--missing"
			options.mode = :missing
		elseif argument == "--prompt"
			options.mode = :prompt
		elseif argument == "--check"
			options.mode = :check
		elseif argument == "--baseline"
			options.mode = :baseline
		elseif argument == "--changed"
			options.changed_only = true
		elseif argument == "--all"
			options.public_only = false
		elseif argument == "--require-parameters"
			options.require_parameters = true
		elseif startswith(argument, "--source=")
			options.source = split(argument, '='; limit=2)[2]
		elseif startswith(argument, "--output=")
			options.output = split(argument, '='; limit=2)[2]
		elseif startswith(argument, "--module=")
			options.module_name = split(argument, '='; limit=2)[2]
		elseif startswith(argument, "--function=")
			options.function_name = split(argument, '='; limit=2)[2]
		elseif startswith(argument, "--max-callsites=")
			options.max_callsites = parse(Int, split(argument, '='; limit=2)[2])
		elseif argument == "--help" || argument == "-h"
			options.mode = :help
		else
			throw(ArgumentError("unknown argument: $(argument)"))
		end
	end
	return options
end

function _changed_julia_files(root::AbstractString)::Vector{String}
	repository::String = DocumentFunction._project_directory(root)
	tracked_text::String = read(`git -C $repository diff --name-only --diff-filter=ACMR HEAD -- '*.jl'`, String)
	untracked_text::String = read(`git -C $repository ls-files --others --exclude-standard -- '*.jl'`, String)
	paths::Vector{String} = String[]
	for relative_path::SubString{String} in split("$(tracked_text)\n$(untracked_text)", '\n')
		candidate::String = joinpath(repository, strip(String(relative_path)))
		if !isempty(strip(relative_path)) && isfile(candidate)
			push!(paths, candidate)
		end
	end
	return unique(sort(paths))
end

function _selected_specs(options::Options)::Vector{DocumentFunction.FunctionSpec}
	specs::Vector{DocumentFunction.FunctionSpec} = DocumentFunction.scanfunctions(
		options.source;
		public_only=options.public_only,
		module_name=options.module_name,
	)
	if !options.changed_only
		return _named_specs(options, specs)
	end
	changed_files::Set{String} = Set(abspath.(_changed_julia_files(options.source)))
	changed_specs::Vector{DocumentFunction.FunctionSpec} = filter(specs) do spec::DocumentFunction.FunctionSpec
		return any(method::DocumentFunction.MethodSpec -> abspath(method.source.path) in changed_files, spec.methods)
	end
	return _named_specs(options, changed_specs)
end

function _named_specs(
	options::Options,
	specs::Vector{DocumentFunction.FunctionSpec},
)::Vector{DocumentFunction.FunctionSpec}
	if isempty(options.function_name)
		return specs
	end
	selected::Vector{DocumentFunction.FunctionSpec} = filter(specs) do spec::DocumentFunction.FunctionSpec
		short_name::String = last(split(spec.qualified_name, '.'))
		return spec.qualified_name == options.function_name || short_name == options.function_name
	end
	if isempty(selected)
		throw(ArgumentError("no scanned function matches --function=$(options.function_name)"))
	end
	return selected
end

function _evidence_paths(root::AbstractString)::Vector{String}
	project::String = DocumentFunction._project_directory(root)
	return filter(isdir, [
		joinpath(project, "test"),
		joinpath(project, "examples"),
		joinpath(project, "docs"),
	])
end

function _render_specs(options::Options, specs::Vector{DocumentFunction.FunctionSpec})::String
	selected::Vector{DocumentFunction.FunctionSpec} = options.mode == :missing ? filter(spec::DocumentFunction.FunctionSpec -> isnothing(spec.existing_doc), specs) : specs
	blocks::Vector{String} = String[]
	project::String = DocumentFunction._project_directory(options.source)
	for spec::DocumentFunction.FunctionSpec in selected
		if options.mode == :prompt
			push!(blocks, DocumentFunction.documentationcontext(
				spec;
				root=project,
				evidence_paths=_evidence_paths(options.source),
				max_callsites=options.max_callsites,
			))
		else
			draft::DocumentFunction.DocumentationDraft = DocumentFunction.draftdocumentation(spec)
			push!(blocks, "# $(spec.qualified_name)\n\n$(DocumentFunction.renderdocstring(draft))")
		end
	end
	return join(blocks, "\n\n---\n\n")
end

function _write_output(text::AbstractString, output::AbstractString)::Nothing
	if isempty(output)
		println(text)
		return nothing
	end
	output_path::String = abspath(output)
	mkpath(dirname(output_path))
	write(output_path, String(text))
	println("Wrote $(output_path)")
	return nothing
end

function main(arguments::Vector{String})::Int
	options::Options = _parse_options(arguments)
	if options.mode == :help
		println(_usage())
		return 0
	end
	if options.mode == :check
		issues::Vector{DocumentFunction.DocumentationIssue} = DocumentFunction.checkdocs(
			options.source;
			public_only=options.public_only,
			require_parameters=options.require_parameters,
			module_name=options.module_name,
		)
		if isempty(issues)
			println("Documentation checks passed.")
			return 0
		end
		println(DocumentFunction.formatissues(issues; root=DocumentFunction._project_directory(options.source)))
		return 1
	end
	if options.mode == :baseline
		path::String = DocumentFunction.writeinventory(
			options.source;
			public_only=options.public_only,
			module_name=options.module_name,
		)
		println("Wrote $(path)")
		return 0
	end
	specs::Vector{DocumentFunction.FunctionSpec} = _selected_specs(options)
	_write_output(_render_specs(options, specs), options.output)
	return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
	exit(main(ARGS))
end
