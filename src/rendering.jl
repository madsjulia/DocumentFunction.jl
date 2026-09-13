function _parameter_label(parameter::ParameterSpec)::String
	label::String = parameter.anonymous ? "" : string(parameter.name)
	if !isnothing(parameter.type_text)
		label *= "::$(parameter.type_text)"
	end
	if parameter.variadic
		label *= "..."
	end
	if !isnothing(parameter.default_text)
		label *= "=$(parameter.default_text)"
	end
	return label
end

function _render_markdown(draft::DocumentationDraft)::String
	io::IOBuffer = IOBuffer()
	for method::MethodSpec in draft.spec.methods
		println(io, "    $(method.signature)")
	end
	println(io)
	println(io, draft.summary.text)

	arguments::Vector{ParameterSpec} = _unique_parameters(draft.spec, PositionalParameter)
	if !isempty(arguments)
		println(io, "\n# Arguments\n")
		for parameter::ParameterSpec in arguments
			println(io, "- `$(_parameter_label(parameter))`: $(draft.arguments[parameter.name].text)")
		end
	end

	keywords::Vector{ParameterSpec} = _unique_parameters(draft.spec, KeywordParameter)
	if !isempty(keywords)
		println(io, "\n# Keywords\n")
		for parameter::ParameterSpec in keywords
			println(io, "- `$(_parameter_label(parameter))`: $(draft.keywords[parameter.name].text)")
		end
	end

	println(io, "\n# Returns\n")
	println(io, draft.returns.text)

	if !isempty(draft.examples)
		println(io, "\n# Examples\n")
		for example::ExampleDraft in draft.examples
			language::String = example.verified && !isnothing(example.output) ? "jldoctest" : "julia"
			println(io, "```$(language)")
			if language == "jldoctest"
				println(io, example.code)
				println(io, "\n# output\n")
				println(io, example.output)
			else
				println(io, example.code)
			end
			println(io, "```")
		end
	end
	return chomp(String(take!(io)))
end

function _escape_docstring_content(text::AbstractString)::String
	escaped::String = replace(String(text), "\\" => "\\\\")
	escaped = replace(escaped, "\$" => "\\\$")
	escaped = replace(escaped, "\"\"\"" => "\\\"\"\"")
	return escaped
end

function _indent_text(text::AbstractString, indentation::AbstractString)::String
	return replace(String(text), "\n" => "\n$(indentation)")
end

"""
    renderdocumentation(draft)

Render a `DocumentationDraft` as Markdown suitable for a Julia docstring.

# Arguments

- `draft`: Reviewed or reviewable documentation content to render.

# Returns

Markdown containing signatures, descriptions, parameters, returns, and examples.
"""
function renderdocumentation(draft::DocumentationDraft)::String
	return _render_markdown(draft)
end

"""
    renderdocstring(draft; indentation="")

Render a static, escaped Julia triple-quoted docstring literal.

The returned source is suitable for review and insertion before a function
definition; it does not perform any file writes.

# Arguments

- `draft`: Reviewed or reviewable documentation content to render.

# Keywords

- `indentation`: Whitespace prepended to every line after the opening delimiter.

# Returns

An escaped Julia triple-quoted docstring literal.
"""
function renderdocstring(
	draft::DocumentationDraft;
	indentation::AbstractString="",
)::String
	indent::String = String(indentation)
	content::String = _indent_text(_escape_docstring_content(_render_markdown(draft)), indent)
	return "\"\"\"\n$(indent)$(content)\n$(indent)\"\"\""
end

function _line_indentation(source::AbstractString, byte_index::Int)::String
	bytes::Vector{UInt8} = Vector{UInt8}(codeunits(String(source)))
	line_start::Int = byte_index
	while line_start > 1 && bytes[line_start - 1] != UInt8('\n')
		line_start -= 1
	end
	indent_bytes::Vector{UInt8} = UInt8[]
	for index::Int in line_start:(byte_index - 1)
		if bytes[index] == UInt8(' ') || bytes[index] == UInt8('\t')
			push!(indent_bytes, bytes[index])
		else
			return ""
		end
	end
	return String(indent_bytes)
end

function _line_prefix_has_code(source::AbstractString, byte_index::Int)::Bool
	bytes::Vector{UInt8} = Vector{UInt8}(codeunits(String(source)))
	line_start::Int = byte_index
	while line_start > 1 && bytes[line_start - 1] != UInt8('\n')
		line_start -= 1
	end
	if line_start == byte_index
		return false
	end
	prefix::String = String(bytes[line_start:(byte_index - 1)])
	return !isempty(strip(prefix))
end

"""
    docpatch(draft; replace_existing=false, allow_unreviewed=false, allow_content_loss=false)

Create a source-hash-protected edit that inserts a static docstring or replaces
the existing attached documentation expression.

Set `replace_existing=true` explicitly when replacing existing documentation.
By default, drafts containing unresolved prose or unverified examples are
rejected; set `allow_unreviewed=true` only to create an explicitly provisional
patch for manual review.
Replacing existing prose requires `allow_content_loss=true` because structured
drafts cannot prove that every intentional paragraph is represented.

# Arguments

- `draft`: Documentation draft and source metadata used to create the edit.

# Keywords

- `replace_existing`: Whether an already attached documentation expression may be replaced.
- `allow_unreviewed`: Whether a draft for which `needsreview` is true may be patched.
- `allow_content_loss`: Whether an existing documentation expression may lose prose not represented by the draft.

# Returns

A `DocPatch` containing the byte range, replacement, and original file hash.
"""
function docpatch(
	draft::DocumentationDraft;
	replace_existing::Bool=false,
	allow_unreviewed::Bool=false,
	allow_content_loss::Bool=false,
)::DocPatch
	if !allow_unreviewed && needsreview(draft)
		throw(ArgumentError("documentation draft still contains unreviewed prose or examples"))
	end
	if isempty(draft.spec.methods)
		throw(ArgumentError("cannot patch a function without source methods"))
	end
	if !isnothing(draft.spec.existing_doc) && isnothing(draft.spec.doc_span)
		throw(ArgumentError("multiple documentation expressions are attached; select and edit one method manually"))
	end
	definition_span::SourceSpan = first(draft.spec.methods).source
	path::String = definition_span.path
	source::String = read(path, String)
	indentation::String = _line_indentation(source, definition_span.first_byte)
	replacement::String = renderdocstring(draft; indentation=indentation)
	first_byte::Int = definition_span.first_byte
	last_byte::Int = definition_span.first_byte - 1

	if !isnothing(draft.spec.doc_span)
		if !replace_existing
			throw(ArgumentError("documentation already exists; set replace_existing=true to replace it"))
		end
		if !allow_content_loss
			throw(ArgumentError("replacing existing documentation requires allow_content_loss=true after manual comparison"))
		end
		doc_span::SourceSpan = draft.spec.doc_span
		path = doc_span.path
		source = read(path, String)
		indentation = _line_indentation(source, doc_span.first_byte)
		replacement = renderdocstring(draft; indentation=indentation)
		first_byte = doc_span.first_byte
		last_byte = doc_span.last_byte
	else
		if _line_prefix_has_code(source, definition_span.first_byte)
			throw(ArgumentError("automatic insertion is unsafe when a function definition follows a same-line macro or expression"))
		end
		replacement *= "\n$(indentation)"
	end

	return DocPatch(path, first_byte, last_byte, replacement, _byte_hash(source))
end

function _apply_byte_edit(source::AbstractString, patch::DocPatch)::String
	bytes::Vector{UInt8} = Vector{UInt8}(codeunits(String(source)))
	replacement::Vector{UInt8} = Vector{UInt8}(codeunits(patch.replacement))
	prefix::Vector{UInt8} = patch.first_byte > 1 ? bytes[1:(patch.first_byte - 1)] : UInt8[]
	suffix_start::Int = patch.last_byte >= patch.first_byte ? patch.last_byte + 1 : patch.first_byte
	suffix::Vector{UInt8} = suffix_start <= length(bytes) ? bytes[suffix_start:end] : UInt8[]
	return String(vcat(prefix, replacement, suffix))
end

"""
    applypatch!(patch)

Apply a `DocPatch` atomically after verifying that the source file still has
the hash captured when the patch was created.

# Arguments

- `patch`: Source-hash-protected documentation edit to apply.

# Returns

`true` after the updated source file is written successfully.
"""
function applypatch!(patch::DocPatch)::Bool
	source::String = read(patch.path, String)
	if _byte_hash(source) != patch.original_file_hash
		throw(ArgumentError("source file changed after the documentation patch was created"))
	end
	updated::String = _apply_byte_edit(source, patch)
	temporary_path::String, temporary_io::IOStream = mktemp(dirname(patch.path))
	write(temporary_io, updated)
	close(temporary_io)
	mv(temporary_path, patch.path; force=true)
	return true
end
