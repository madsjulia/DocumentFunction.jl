"""
Distinguish positional parameters from keyword parameters in source metadata.
"""
@enum ParameterKind::UInt8 PositionalParameter KeywordParameter

"""
Describe a byte-accurate span in a Julia source file.

`path` is used for editing and diagnostics, while rendered documentation uses
repository-relative paths supplied by the caller.
"""
struct SourceSpan
	path::String
	first_byte::Int
	last_byte::Int
	first_line::Int
	last_line::Int
end

"""
Describe one positional or keyword parameter exactly as written in source.

`type_text` and `default_text` are syntax strings and are `nothing` when the
source does not declare them.
"""
struct ParameterSpec
	name::Symbol
	kind::ParameterKind
	type_text::Union{Nothing, String}
	default_text::Union{Nothing, String}
	required::Bool
	variadic::Bool
	anonymous::Bool
end

"""
Describe one source-defined method without evaluating the package.
"""
struct MethodSpec
	signature::String
	parameters::Vector{ParameterSpec}
	declared_return_type::Union{Nothing, String}
	source::SourceSpan
	source_text::String
end

"""
Collect source metadata for all scanned methods of a Julia function.

`existing_doc` contains the literal documentation text when available and the
unevaluated documentation expression otherwise.
"""
struct FunctionSpec
	qualified_name::String
	methods::Vector{MethodSpec}
	is_exported::Bool
	is_public::Bool
	existing_doc::Union{Nothing, String}
	doc_span::Union{Nothing, SourceSpan}
	source_hash::String
end

"""
Represent proposed prose together with its evidence and review status.
"""
struct DescriptionDraft
	text::String
	confidence::Float64
	provenance::Symbol
	evidence::String
	needs_review::Bool
end

"""
Represent a proposed Julia example.

`complete` means that no placeholder remains, while `verified` means that the
example has actually been executed successfully by the authoring workflow.
"""
struct ExampleDraft
	code::String
	output::Union{Nothing, String}
	complete::Bool
	verified::Bool
	unresolved::Vector{Symbol}
	provenance::Symbol
end

"""
Record the result of executing an example twice in isolated Julia processes.
"""
struct ExampleVerification
	example::ExampleDraft
	success::Bool
	deterministic::Bool
	timed_out::Bool
	stdout::String
	stderr::String
end

"""
Collect a reviewable documentation draft for a `FunctionSpec`.
"""
struct DocumentationDraft
	spec::FunctionSpec
	summary::DescriptionDraft
	arguments::Dict{Symbol, DescriptionDraft}
	keywords::Dict{Symbol, DescriptionDraft}
	returns::DescriptionDraft
	examples::Vector{ExampleDraft}
	warnings::Vector{String}
end

"""
Report one deterministic documentation coverage or freshness problem.
"""
struct DocumentationIssue
	code::Symbol
	qualified_name::String
	message::String
	source::Union{Nothing, SourceSpan}
end

"""
Represent a byte-addressed, source-hash-protected docstring edit.
"""
struct DocPatch
	path::String
	first_byte::Int
	last_byte::Int
	replacement::String
	original_file_hash::String
end
