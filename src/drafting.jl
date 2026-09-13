const _PARAMETER_RULES = Dict{Symbol, Tuple{String, Float64}}(
	:atol => ("Absolute tolerance used by the operation.", 0.78),
	:filename => ("Filesystem path used by the operation.", 0.62),
	:io => ("Input/output stream used by the operation.", 0.72),
	:location => ("Whether to include source-location information.", 0.82),
	:maxiter => ("Maximum number of iterations.", 0.82),
	:max_iter => ("Maximum number of iterations.", 0.82),
	:overwrite => ("Whether an existing destination may be replaced.", 0.78),
	:path => ("Filesystem path used by the operation.", 0.62),
	:quiet => ("Whether to suppress non-error progress output.", 0.82),
	:recursive => ("Whether to include nested entries.", 0.78),
	:rng => ("Random-number generator used by the operation.", 0.86),
	:rtol => ("Relative tolerance used by the operation.", 0.78),
	:seed => ("Seed used to initialize random-number generation.", 0.82),
	:verbose => ("Whether to emit detailed progress information.", 0.82),
)

function _dictionary_text(values::AbstractDict, name::Symbol)::Union{Nothing, String}
	if haskey(values, name)
		return String(values[name])
	end
	name_string::String = string(name)
	if haskey(values, name_string)
		return String(values[name_string])
	end
	return nothing
end

function _parameter_name_from_label(label::AbstractString)::Symbol
	name::String = strip(String(label))
	name = first(split(name, "::"))
	name = first(split(name, '='))
	name = replace(name, "..." => "")
	return Symbol(strip(name))
end

function _existing_parameter_text(doc::AbstractString)::Dict{Symbol, String}
	result::Dict{Symbol, String} = Dict{Symbol, String}()
	for line::SubString{String} in split(String(doc), '\n')
		matched::Union{Nothing, RegexMatch} = match(r"^\s*[-*]\s+`([^`]+)`.*?:\s*(.+?)\s*$", line)
		if !isnothing(matched)
			name::Symbol = _parameter_name_from_label(String(matched.captures[1]))
			result[name] = String(matched.captures[2])
		end
	end
	for matched::RegexMatch in eachmatch(r"\"([A-Za-z_][A-Za-z0-9_!]*)\"\s*=>\s*\"([^\"]+)\"", String(doc))
		name::Symbol = Symbol(String(matched.captures[1]))
		if !haskey(result, name)
			result[name] = String(matched.captures[2])
		end
	end
	return result
end

function _existing_summary(doc::Union{Nothing, String})::Union{Nothing, String}
	if isnothing(doc)
		return nothing
	end
	legacy_match::Union{Nothing, RegexMatch} = match(r"maintext\s*=\s*\"([^\"]+)\"", doc)
	if !isnothing(legacy_match)
		return String(legacy_match.captures[1])
	end
	skipping_signature::Bool = false
	for line::SubString{String} in split(doc, '\n')
		candidate::String = strip(String(line))
		if isempty(candidate)
			skipping_signature = false
			continue
		end
		if skipping_signature
			continue
		end
		if startswith(String(line), "    ") || occursin(r"^[A-Za-z_][A-Za-z0-9_.!]*\s*\(", candidate)
			skipping_signature = true
			continue
		end
		if startswith(candidate, "#") || startswith(candidate, "```")
			continue
		end
		if startswith(candidate, "\"\"\"") || startswith(candidate, "\$(")
			continue
		end
		return candidate
	end
	return nothing
end

function _existing_section(
	doc::Union{Nothing, String},
	heading::AbstractString,
)::Union{Nothing, String}
	if isnothing(doc)
		return nothing
	end
	lines::Vector{SubString{String}} = split(doc, '\n')
	start_index::Union{Nothing, Int} = nothing
	for (index::Int, line::SubString{String}) in enumerate(lines)
		if strip(String(line)) == "# $(heading)"
			start_index = index + 1
			break
		end
	end
	if isnothing(start_index)
		return nothing
	end
	section_lines::Vector{String} = String[]
	for line::SubString{String} in lines[start_index:end]
		if startswith(strip(String(line)), "# ")
			break
		end
		push!(section_lines, String(line))
	end
	section::String = strip(join(section_lines, "\n"))
	return isempty(section) ? nothing : section
end

function _humanize_identifier(name::AbstractString)::String
	without_bang::String = replace(String(name), "!" => "")
	with_spaces::String = replace(without_bang, r"([a-z0-9])([A-Z])" => s"\1 \2")
	return lowercase(replace(with_spaces, '_' => ' '))
end

function _summary_template(name::AbstractString)::DescriptionDraft
	short_name::String = _last_binding_component(name)
	words::String = _humanize_identifier(short_name)
	verb_templates::Vector{Pair{String, String}} = [
		"get" => "Return",
		"read" => "Read",
		"load" => "Load",
		"parse" => "Parse",
		"write" => "Write",
		"save" => "Save",
		"compute" => "Compute",
		"calculate" => "Calculate",
		"render" => "Render",
		"scan" => "Scan",
		"check" => "Check",
		"update" => "Update",
		"create" => "Create",
		"document" => "Document",
	]
	for template::Pair{String, String} in verb_templates
		prefix::String = first(template)
		if startswith(words, prefix)
			remainder::String = strip(replace(words, Regex("^$(prefix)") => ""; count=1))
			if !isempty(remainder)
				return DescriptionDraft(
					"$(last(template)) $(remainder).",
					0.55,
					:name_template,
					"function-name verb template",
					true,
				)
			end
		end
	end
	return DescriptionDraft(
		"TODO: Describe the observable behavior of `$(short_name)`.",
		0.0,
		:unresolved,
		"no reliable semantic evidence",
		true,
	)
end

function _type_description(parameter::ParameterSpec)::Union{Nothing, DescriptionDraft}
	type_text::String = isnothing(parameter.type_text) ? "" : parameter.type_text
	name::String = string(parameter.name)
	if parameter.variadic && parameter.kind == KeywordParameter
		return DescriptionDraft(
			"Additional keyword arguments forwarded by the operation.",
			0.72,
			:type_template,
			"keyword-varargs syntax",
			true,
		)
	end
	if parameter.variadic
		return DescriptionDraft(
			"Additional positional arguments supplied to the operation.",
			0.68,
			:type_template,
			"positional-varargs syntax",
			true,
		)
	end
	if occursin("Bool", type_text)
		return DescriptionDraft(
			"Whether to enable the `$(_humanize_identifier(name))` option.",
			0.58,
			:type_template,
			"declared Boolean type",
			true,
		)
	end
	if occursin("Function", type_text)
		return DescriptionDraft(
			"Callable supplied as `$(name)`.",
			0.60,
			:type_template,
			"declared callable type",
			true,
		)
	end
	if occursin("AbstractRNG", type_text) || endswith(type_text, "RNG")
		return DescriptionDraft(
			"Random-number generator used by the operation.",
			0.86,
			:type_template,
			"declared random-number-generator type",
			true,
		)
	end
	if occursin("IO", type_text)
		return DescriptionDraft(
			"Input/output stream used by the operation.",
			0.72,
			:type_template,
			"declared stream type",
			true,
		)
	end
	return nothing
end

function _parameter_description(
	parameter::ParameterSpec,
	explicit::AbstractDict,
	existing::Dict{Symbol, String},
)::DescriptionDraft
	explicit_text::Union{Nothing, String} = _dictionary_text(explicit, parameter.name)
	if !isnothing(explicit_text)
		return DescriptionDraft(explicit_text, 1.0, :explicit, "caller-provided description", false)
	end
	if haskey(existing, parameter.name)
		return DescriptionDraft(
			existing[parameter.name],
			0.98,
			:existing_doc,
			"existing documentation",
			false,
		)
	end
	if haskey(_PARAMETER_RULES, parameter.name)
		text::String, confidence::Float64 = _PARAMETER_RULES[parameter.name]
		return DescriptionDraft(text, confidence, :name_type_template, "conservative parameter rule", true)
	end
	type_draft::Union{Nothing, DescriptionDraft} = _type_description(parameter)
	if !isnothing(type_draft)
		return type_draft
	end
	return DescriptionDraft(
		"TODO: Describe `$(parameter.name)` from its use in the implementation and tests.",
		0.0,
		:unresolved,
		"name and type are insufficient evidence",
		true,
	)
end

function _unique_parameters(spec::FunctionSpec, kind::ParameterKind)::Vector{ParameterSpec}
	parameters::Vector{ParameterSpec} = ParameterSpec[]
	seen::Set{Symbol} = Set{Symbol}()
	for method::MethodSpec in spec.methods
		for parameter::ParameterSpec in method.parameters
			if parameter.kind == kind && !(parameter.name in seen)
				push!(parameters, parameter)
				push!(seen, parameter.name)
			end
		end
	end
	return parameters
end

function _example_value(
	parameter::ParameterSpec,
	values::AbstractDict,
)::Tuple{String, Bool}
	explicit::Union{Nothing, String} = _dictionary_text(values, parameter.name)
	if !isnothing(explicit)
		return explicit, true
	end
	if !isnothing(parameter.default_text)
		return parameter.default_text, true
	end
	type_text::String = isnothing(parameter.type_text) ? "" : parameter.type_text
	if occursin("Matrix", type_text)
		matrix_value::String = if occursin("Bool", type_text)
			"false"
		elseif occursin(r"(^|\W)(Int|Integer|Signed|Unsigned)(\W|$)", type_text)
			"1"
		elseif occursin("String", type_text)
			"\"value\""
		elseif occursin("Symbol", type_text)
			":value"
		else
			"1.0"
		end
		return "reshape([$(matrix_value)], 1, 1)", true
	end
	if occursin("Vector", type_text)
		vector_value::String = if occursin("Bool", type_text)
			"false"
		elseif occursin(r"(^|\W)(Int|Integer|Signed|Unsigned)(\W|$)", type_text)
			"1"
		elseif occursin("String", type_text)
			"\"value\""
		elseif occursin("Symbol", type_text)
			":value"
		else
			"1.0"
		end
		return "[$(vector_value)]", true
	end
	if occursin("Bool", type_text)
		return "false", true
	end
	if occursin(r"(^|\W)(Int|Integer|Signed|Unsigned)(\W|$)", type_text)
		return "1", true
	end
	if occursin("Float", type_text) || occursin("Real", type_text) || occursin("Number", type_text)
		return "1.0", true
	end
	if occursin("String", type_text)
		return "\"value\"", true
	end
	if occursin("Symbol", type_text)
		return ":value", true
	end
	if occursin("Function", type_text)
		return "identity", true
	end
	if occursin("NamedTuple", type_text)
		return "NamedTuple()", true
	end
	if occursin("Tuple", type_text)
		return "()", true
	end
	if occursin("Nothing", type_text)
		return "nothing", true
	end
	if occursin("IO", type_text)
		return "IOBuffer()", true
	end
	return "<$(parameter.name)>", false
end

"""
    exampledraft(spec; values=Dict(), include_optional_keywords=false, method_index=1)

Create a conservative call example for one source method.

The result is a template, not a verified execution, unless the caller supplies
`verified=true` after executing it in the target project.

# Arguments

- `spec`: Structured function metadata used to construct the call.

# Keywords

- `values`: Julia source expressions keyed by argument or keyword name.
- `include_optional_keywords`: Whether optional keywords should appear with their source defaults.
- `method_index`: One-based source-method index used to construct the call.
- `output`: Expected textual output, when known.
- `verified`: Whether the caller has already executed and validated the supplied example.

# Returns

An `ExampleDraft` recording the code, unresolved placeholders, provenance, and verification state.
"""
function exampledraft(
	spec::FunctionSpec;
	values::AbstractDict=Dict{Symbol, String}(),
	include_optional_keywords::Bool=false,
	method_index::Int=1,
	output::Union{Nothing, AbstractString}=nothing,
	verified::Bool=false,
)::ExampleDraft
	if isempty(spec.methods)
		return ExampleDraft("", nothing, false, false, Symbol[], :unresolved)
	end
	if !(1 <= method_index <= length(spec.methods))
		throw(ArgumentError("method_index must identify one of the extracted source methods"))
	end
	method::MethodSpec = spec.methods[method_index]
	positional_values::Vector{String} = String[]
	keyword_values::Vector{String} = String[]
	unresolved::Vector{Symbol} = Symbol[]

	for parameter::ParameterSpec in method.parameters
		if parameter.variadic
			continue
		end
		value::String, resolved::Bool = _example_value(parameter, values)
		if parameter.kind == PositionalParameter
			if isnothing(parameter.default_text) || haskey(values, parameter.name) || haskey(values, string(parameter.name))
				push!(positional_values, value)
			end
		elseif parameter.required || include_optional_keywords || haskey(values, parameter.name) || haskey(values, string(parameter.name))
			push!(keyword_values, "$(parameter.name)=$(value)")
		end
		if !resolved && (parameter.required || parameter.kind == PositionalParameter)
			push!(unresolved, parameter.name)
		end
	end

	arguments::String = join(positional_values, ", ")
	if !isempty(keyword_values)
		arguments *= "; " * join(keyword_values, ", ")
	end
	root_module::String = first(split(spec.qualified_name, '.'))
	import_line::String = occursin(r"^[A-Za-z_][A-Za-z0-9_]*$", root_module) ? "import $(root_module)\n" : ""
	code::String = "$(import_line)$(spec.qualified_name)($(arguments))"
	complete::Bool = isempty(unresolved)
	return ExampleDraft(
		code,
		isnothing(output) ? nothing : String(output),
		complete,
		verified && complete,
		unresolved,
		isempty(values) ? :type_template : :explicit_values,
	)
end

function _return_description(
	spec::FunctionSpec,
	explicit::AbstractString,
	existing_doc::Union{Nothing, String},
)::DescriptionDraft
	if !isempty(explicit)
		return DescriptionDraft(String(explicit), 1.0, :explicit, "caller-provided return description", false)
	end
	existing_return::Union{Nothing, String} = _existing_section(existing_doc, "Returns")
	if !isnothing(existing_return)
		return DescriptionDraft(existing_return, 0.98, :existing_doc, "existing documentation", false)
	end
	return_types::Vector{String} = unique([
		method.declared_return_type
		for method::MethodSpec in spec.methods
		if !isnothing(method.declared_return_type)
	])
	if length(return_types) == 1
		return_type::String = first(return_types)
		if return_type == "Nothing"
			return DescriptionDraft("Return `nothing`.", 0.90, :declared_return_type, "declared `Nothing` return annotation", false)
		end
		return DescriptionDraft(
			"Return a value declared as `$(return_type)`.",
			0.82,
			:declared_return_type,
			"source return annotation",
			true,
		)
	end
	return DescriptionDraft(
		"TODO: Describe the return value from implementation and test evidence.",
		0.0,
		:unresolved,
		"no consistent declared return annotation",
		true,
	)
end

"""
    draftdocumentation(spec; summary="", argtext=Dict(), keytext=Dict(), returntext="", example_values=Dict(), example_method=1)

Build an offline, reviewable documentation draft from extracted facts,
caller-provided descriptions, existing prose, and conservative templates.

Name- or type-derived prose is marked `needs_review`; unresolved semantics are
rendered as explicit `TODO` items rather than invented descriptions.

# Arguments

- `spec`: Structured function metadata from `scanfunctions` or `functionspec`.

# Keywords

- `summary`: Evidence-backed function summary supplied by the caller.
- `argtext`: Positional-argument descriptions keyed by `Symbol` or `String` names.
- `keytext`: Keyword descriptions keyed by `Symbol` or `String` names.
- `returntext`: Evidence-backed description of the return value.
- `example_values`: Julia source expressions used to resolve example arguments.
- `example_method`: One-based source-method index used to construct the example.
- `example_output`: Expected example output, when known.
- `example_verified`: Whether the supplied example and output were already executed and validated.

# Returns

A `DocumentationDraft` whose inferred fields retain confidence, provenance, evidence, and review status.
"""
function draftdocumentation(
	spec::FunctionSpec;
	summary::AbstractString="",
	argtext::AbstractDict=Dict{Symbol, String}(),
	keytext::AbstractDict=Dict{Symbol, String}(),
	returntext::AbstractString="",
	example_values::AbstractDict=Dict{Symbol, String}(),
	example_method::Int=1,
	example_output::Union{Nothing, AbstractString}=nothing,
	example_verified::Bool=false,
)::DocumentationDraft
	existing_text::Dict{Symbol, String} = isnothing(spec.existing_doc) ? Dict{Symbol, String}() : _existing_parameter_text(spec.existing_doc)
	existing_summary::Union{Nothing, String} = _existing_summary(spec.existing_doc)
	summary_draft::DescriptionDraft = if !isempty(summary)
		DescriptionDraft(String(summary), 1.0, :explicit, "caller-provided summary", false)
	elseif !isnothing(existing_summary)
		DescriptionDraft(existing_summary, 0.98, :existing_doc, "existing documentation", false)
	else
		_summary_template(spec.qualified_name)
	end

	arguments::Dict{Symbol, DescriptionDraft} = Dict{Symbol, DescriptionDraft}()
	for parameter::ParameterSpec in _unique_parameters(spec, PositionalParameter)
		arguments[parameter.name] = _parameter_description(parameter, argtext, existing_text)
	end
	keywords::Dict{Symbol, DescriptionDraft} = Dict{Symbol, DescriptionDraft}()
	for parameter::ParameterSpec in _unique_parameters(spec, KeywordParameter)
		keywords[parameter.name] = _parameter_description(parameter, keytext, existing_text)
	end
	example::ExampleDraft = exampledraft(
		spec;
		values=example_values,
		method_index=example_method,
		output=example_output,
		verified=example_verified,
	)
	warnings::Vector{String} = String[]
	if !example.complete
		push!(warnings, "Example requires explicit values for: $(join(string.(example.unresolved), ", ")).")
	elseif !example.verified
		push!(warnings, "Example is syntactically complete but has not been executed in the target project.")
	end
	return DocumentationDraft(
		spec,
		summary_draft,
		arguments,
		keywords,
		_return_description(spec, returntext, spec.existing_doc),
		[example],
		warnings,
	)
end

"""
    needsreview(draft)

Return `true` when any generated prose or example still needs semantic or
execution review.

# Arguments

- `draft`: Documentation draft to inspect.

# Returns

`true` when any description needs review or any example remains unverified.
"""
function needsreview(draft::DocumentationDraft)::Bool
	if draft.summary.needs_review || draft.returns.needs_review
		return true
	end
	if any(description::DescriptionDraft -> description.needs_review, values(draft.arguments))
		return true
	end
	if any(description::DescriptionDraft -> description.needs_review, values(draft.keywords))
		return true
	end
	return any(example::ExampleDraft -> !example.verified, draft.examples)
end
