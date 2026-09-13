import JuliaSyntax
import SHA

struct _DocInfo
	text::String
	span::SourceSpan
end

struct _FunctionDefinition
	qualified_name::String
	method::Union{Nothing, MethodSpec}
	doc::Union{Nothing, _DocInfo}
	source_text::String
end

function _normalized_source(text::AbstractString)::String
	return replace(String(text), "\r\n" => "\n", "\r" => "\n")
end

function _source_hash(text::AbstractString)::String
	return bytes2hex(SHA.sha256(codeunits(_normalized_source(text))))
end

function _byte_hash(text::AbstractString)::String
	return bytes2hex(SHA.sha256(codeunits(String(text))))
end

function _source_span(path::AbstractString, node::JuliaSyntax.SyntaxNode)::SourceSpan
	range::UnitRange{Int} = JuliaSyntax.byte_range(node)
	text::String = String(JuliaSyntax.sourcetext(node))
	first_line::Int = JuliaSyntax.source_line(node)
	last_line::Int = first_line + count(==('\n'), text)
	return SourceSpan(String(path), first(range), last(range), first_line, last_line)
end

function _expression_text(value::Any)::String
	if value isa AbstractString || value isa Char
		return repr(value)
	end
	return string(value)
end

function _unwrap_signature(signature::Any)::Tuple{Union{Nothing, Expr}, Union{Nothing, String}}
	current::Any = signature
	while current isa Expr && current.head == :where
		current = current.args[1]
	end
	return_type::Union{Nothing, String} = nothing
	if current isa Expr && current.head == :(::)
		return_type = _expression_text(current.args[2])
		current = current.args[1]
	end
	if current isa Expr && current.head == :call
		return current, return_type
	end
	return nothing, return_type
end

function _function_signature(expression::Expr)::Union{Nothing, Any}
	if expression.head == :function && !isempty(expression.args)
		return expression.args[1]
	end
	if expression.head == :(=) && !isempty(expression.args)
		return expression.args[1]
	end
	return nothing
end

function _call_name(call::Expr)::String
	binding::Any = call.args[1]
	if binding isa Symbol
		return string(binding)
	end
	if binding isa Expr && binding.head == :(::)
		return _expression_text(binding.args[1])
	end
	return _expression_text(binding)
end

function _parameter_name(value::Any)::Symbol
	if value isa Symbol
		return value
	end
	return Symbol(_expression_text(value))
end

function _parameter_spec(value::Any, kind::ParameterKind, ordinal::Int)::ParameterSpec
	current::Any = value
	variadic::Bool = false
	anonymous::Bool = false
	default_text::Union{Nothing, String} = nothing
	type_text::Union{Nothing, String} = nothing

	if current isa Expr && current.head == :...
		variadic = true
		current = current.args[1]
	end
	if current isa Expr && (current.head == :kw || current.head == :(=))
		default_text = _expression_text(current.args[2])
		current = current.args[1]
	end
	if current isa Expr && current.head == :(::)
		if length(current.args) == 1
			type_text = _expression_text(current.args[1])
			current = Symbol("_arg$(ordinal)")
			anonymous = true
		else
			type_text = _expression_text(current.args[2])
			current = current.args[1]
		end
	end
	if current isa Expr && current.head == :...
		variadic = true
		current = current.args[1]
	end

	required::Bool = isnothing(default_text) && !variadic
	return ParameterSpec(
		_parameter_name(current),
		kind,
		type_text,
		default_text,
		required,
		variadic,
		anonymous,
	)
end

function _method_spec(path::AbstractString, node::JuliaSyntax.SyntaxNode)::Union{Nothing, Tuple{String, MethodSpec}}
	expression::Any = Expr(node)
	if !(expression isa Expr)
		return nothing
	end
	signature_expression::Union{Nothing, Any} = _function_signature(expression)
	if isnothing(signature_expression)
		return nothing
	end
	call::Union{Nothing, Expr}, return_type::Union{Nothing, String} = _unwrap_signature(signature_expression)
	if isnothing(call)
		return nothing
	end

	parameters::Vector{ParameterSpec} = ParameterSpec[]
	for (ordinal::Int, value::Any) in enumerate(call.args[2:end])
		if value isa Expr && value.head == :parameters
			for (keyword_ordinal::Int, keyword::Any) in enumerate(value.args)
				push!(parameters, _parameter_spec(keyword, KeywordParameter, keyword_ordinal))
			end
		else
			push!(parameters, _parameter_spec(value, PositionalParameter, ordinal))
		end
	end

	name::String = _call_name(call)
	method::MethodSpec = MethodSpec(
		_expression_text(signature_expression),
		parameters,
		return_type,
		_source_span(path, node),
		String(JuliaSyntax.sourcetext(node)),
	)
	return name, method
end

function _binding_name(expression::Any)::Union{Nothing, String}
	if expression isa Symbol
		return string(expression)
	end
	if expression isa QuoteNode && expression.value isa Symbol
		return string(expression.value)
	end
	if expression isa Expr
		if expression.head == :function && !isempty(expression.args)
			return _binding_name(expression.args[1])
		end
		if expression.head == :call
			return _call_name(expression)
		end
		if expression.head == :where || expression.head == :(::)
			return _binding_name(expression.args[1])
		end
		if expression.head == :.
			return _expression_text(expression)
		end
	end
	return nothing
end

function _doc_text(node::JuliaSyntax.SyntaxNode)::String
	expression::Any = Expr(node)
	if expression isa AbstractString
		return String(expression)
	end
	return String(JuliaSyntax.sourcetext(node))
end

function _syntax_children(node::JuliaSyntax.SyntaxNode)::Vector{JuliaSyntax.SyntaxNode}
	children::Union{Nothing, AbstractVector} = JuliaSyntax.children(node)
	return isnothing(children) ? JuliaSyntax.SyntaxNode[] : collect(children)
end

function _collect_metadata!(
	node::JuliaSyntax.SyntaxNode,
	path::AbstractString,
	exported::Set{String},
	public_names::Set{String},
	docs::Dict{String, _DocInfo},
	modules::Vector{String},
)::Nothing
	kind::JuliaSyntax.Kind = JuliaSyntax.kind(node)
	children::Vector{JuliaSyntax.SyntaxNode} = _syntax_children(node)
	if kind == JuliaSyntax.K"module" || kind == JuliaSyntax.K"baremodule"
		module_nodes::Vector{JuliaSyntax.SyntaxNode}, updated_modules::Vector{String} = _module_children(children, modules)
		for child::JuliaSyntax.SyntaxNode in module_nodes
			_collect_metadata!(child, path, exported, public_names, docs, updated_modules)
		end
		return nothing
	end

	if kind == JuliaSyntax.K"export" || kind == JuliaSyntax.K"public"
		destination::Set{String} = kind == JuliaSyntax.K"export" ? exported : public_names
		for child::JuliaSyntax.SyntaxNode in children
			visibility_name::Union{Nothing, String} = _binding_name(Expr(child))
			if !isnothing(visibility_name)
				push!(destination, _qualified_name(modules, visibility_name))
			end
		end
	elseif kind == JuliaSyntax.K"doc" && length(children) >= 2
		implicit_doc_node::JuliaSyntax.SyntaxNode = first(children)
		implicit_target_node::JuliaSyntax.SyntaxNode = last(children)
		implicit_name::Union{Nothing, String} = _binding_name(Expr(implicit_target_node))
		if !isnothing(implicit_name)
			docs[_qualified_name(modules, implicit_name)] = _DocInfo(_doc_text(implicit_doc_node), _source_span(path, implicit_doc_node))
		end
	elseif kind == JuliaSyntax.K"macrocall" && length(children) >= 3
		macro_name::String = string(Expr(first(children)))
		if macro_name == "@doc"
			explicit_doc_node::JuliaSyntax.SyntaxNode = children[2]
			explicit_target_node::JuliaSyntax.SyntaxNode = last(children)
			explicit_name::Union{Nothing, String} = _binding_name(Expr(explicit_target_node))
			if !isnothing(explicit_name)
				docs[_qualified_name(modules, explicit_name)] = _DocInfo(_doc_text(explicit_doc_node), _source_span(path, explicit_doc_node))
			end
		end
	end

	for child::JuliaSyntax.SyntaxNode in children
		_collect_metadata!(child, path, exported, public_names, docs, modules)
	end
	return nothing
end

function _qualified_name(modules::Vector{String}, name::AbstractString)::String
	name_string::String = String(name)
	if isempty(modules) || occursin('.', name_string)
		return name_string
	end
	return join([modules; name_string], ".")
end

function _module_children(
	children::Vector{JuliaSyntax.SyntaxNode},
	modules::Vector{String},
)::Tuple{Vector{JuliaSyntax.SyntaxNode}, Vector{String}}
	if isempty(children)
		return children, modules
	end
	module_name::String = strip(String(JuliaSyntax.sourcetext(first(children))))
	updated_modules::Vector{String} = copy(modules)
	if isempty(updated_modules) || last(updated_modules) != module_name
		push!(updated_modules, module_name)
	end
	return children[2:end], updated_modules
end

function _collect_definitions!(
	definitions::Vector{_FunctionDefinition},
	node::JuliaSyntax.SyntaxNode,
	path::AbstractString,
	modules::Vector{String},
	docs::Dict{String, _DocInfo},
	direct_doc::Union{Nothing, _DocInfo}=nothing,
)::Nothing
	kind::JuliaSyntax.Kind = JuliaSyntax.kind(node)
	children::Vector{JuliaSyntax.SyntaxNode} = _syntax_children(node)

	if kind == JuliaSyntax.K"doc" && length(children) >= 2
		doc_node::JuliaSyntax.SyntaxNode = first(children)
		target_node::JuliaSyntax.SyntaxNode = last(children)
		if JuliaSyntax.kind(target_node) == JuliaSyntax.K"function"
			info:: _DocInfo = _DocInfo(_doc_text(doc_node), _source_span(path, doc_node))
			_collect_definitions!(definitions, target_node, path, modules, docs, info)
			return nothing
		end
	end

	if kind == JuliaSyntax.K"function"
		parsed::Union{Nothing, Tuple{String, MethodSpec}} = _method_spec(path, node)
		if !isnothing(parsed)
			parsed_name::String, method::MethodSpec = parsed
			method_qualified_name::String = _qualified_name(modules, parsed_name)
			attached_doc::Union{Nothing, _DocInfo} = direct_doc
			if isnothing(attached_doc)
				attached_doc = get(docs, method_qualified_name, nothing)
			end
			push!(definitions, _FunctionDefinition(method_qualified_name, method, attached_doc, method.source_text))
		else
			expression::Any = Expr(node)
			declaration_name::Union{Nothing, String} = _binding_name(expression)
			if !isnothing(declaration_name)
				declaration_qualified_name::String = _qualified_name(modules, declaration_name)
				declaration_doc::Union{Nothing, _DocInfo} = direct_doc
				if isnothing(declaration_doc)
					declaration_doc = get(docs, declaration_qualified_name, nothing)
				end
				push!(definitions, _FunctionDefinition(
					declaration_qualified_name,
					nothing,
					declaration_doc,
					String(JuliaSyntax.sourcetext(node)),
				))
			end
		end
		return nothing
	end

	if kind == JuliaSyntax.K"module" || kind == JuliaSyntax.K"baremodule"
		module_nodes::Vector{JuliaSyntax.SyntaxNode}, updated_modules::Vector{String} = _module_children(children, modules)
		for child::JuliaSyntax.SyntaxNode in module_nodes
			_collect_definitions!(definitions, child, path, updated_modules, docs)
		end
		return nothing
	end

	for child::JuliaSyntax.SyntaxNode in children
		_collect_definitions!(definitions, child, path, modules, docs)
	end
	return nothing
end

function _last_binding_component(name::AbstractString)::String
	parts::Vector{SubString{String}} = split(String(name), '.')
	return String(last(parts))
end

function _project_name(path::AbstractString)::String
	candidate::String = isdir(path) ? abspath(path) : dirname(abspath(path))
	while true
		project_path::String = joinpath(candidate, "Project.toml")
		if isfile(project_path)
			project_text::String = read(project_path, String)
			name_match::Union{Nothing, RegexMatch} = match(r"(?m)^name\s*=\s*\"([^\"]+)\"", project_text)
			if !isnothing(name_match)
				return String(name_match.captures[1])
			end
		end
		parent::String = dirname(candidate)
		if parent == candidate
			return ""
		end
		candidate = parent
	end
end

function _source_files(path::AbstractString)::Vector{String}
	absolute_path::String = abspath(path)
	if isfile(absolute_path)
		return endswith(lowercase(absolute_path), ".jl") ? [absolute_path] : String[]
	end
	files::Vector{String} = String[]
	for (root::String, directories::Vector{String}, names::Vector{String}) in walkdir(absolute_path)
		sort!(directories)
		for name::String in sort(names)
			if endswith(lowercase(name), ".jl")
				push!(files, joinpath(root, name))
			end
		end
	end
	return files
end

function _scan_file(
	path::AbstractString,
	modules::Vector{String},
)::Tuple{Vector{_FunctionDefinition}, Set{String}, Set{String}}
	absolute_path::String = abspath(path)
	source::String = read(absolute_path, String)
	tree::JuliaSyntax.SyntaxNode = JuliaSyntax.parseall(
		JuliaSyntax.SyntaxNode,
		source;
		filename=absolute_path,
	)
	exported::Set{String} = Set{String}()
	public_names::Set{String} = Set{String}()
	docs::Dict{String, _DocInfo} = Dict{String, _DocInfo}()
	_collect_metadata!(tree, absolute_path, exported, public_names, docs, modules)
	definitions::Vector{_FunctionDefinition} = _FunctionDefinition[]
	_collect_definitions!(definitions, tree, absolute_path, modules, docs)
	return definitions, exported, public_names
end

function _group_definitions(
	definitions::Vector{_FunctionDefinition},
	exported::Set{String},
	public_names::Set{String},
)::Vector{FunctionSpec}
	grouped::Dict{String, Vector{_FunctionDefinition}} = Dict{String, Vector{_FunctionDefinition}}()
	order::Vector{String} = String[]
	for definition::_FunctionDefinition in definitions
		if !haskey(grouped, definition.qualified_name)
			grouped[definition.qualified_name] = _FunctionDefinition[]
			push!(order, definition.qualified_name)
		end
		push!(grouped[definition.qualified_name], definition)
	end

	functions::Vector{FunctionSpec} = FunctionSpec[]
	for qualified_name::String in order
		entries::Vector{_FunctionDefinition} = grouped[qualified_name]
		methods::Vector{MethodSpec} = MethodSpec[
			entry.method
			for entry::_FunctionDefinition in entries
			if !isnothing(entry.method)
		]
		documents::Vector{_DocInfo} = _DocInfo[]
		for entry::_FunctionDefinition in entries
			if !isnothing(entry.doc)
				document::_DocInfo = entry.doc
				duplicate::Bool = any(documents) do existing::_DocInfo
					existing.span.path == document.span.path &&
						existing.span.first_byte == document.span.first_byte &&
						existing.span.last_byte == document.span.last_byte
				end
				if !duplicate
					push!(documents, document)
				end
			end
		end
		existing_doc::Union{Nothing, String} = if isempty(documents)
			nothing
		elseif length(documents) == 1
			first(documents).text
		else
			join([
				"# Method documentation $(index)\n\n$(document.text)"
				for (index::Int, document::_DocInfo) in enumerate(documents)
			], "\n\n")
		end
		doc_span::Union{Nothing, SourceSpan} = length(documents) == 1 ? first(documents).span : nothing
		is_exported::Bool = qualified_name in exported
		is_public::Bool = is_exported || qualified_name in public_names
		hash_input::String = join(unique([entry.source_text for entry::_FunctionDefinition in entries]), "\n\n")
		push!(functions, FunctionSpec(
			qualified_name,
			methods,
			is_exported,
			is_public,
			existing_doc,
			doc_span,
			_source_hash(hash_input),
		))
	end
	return functions
end

"""
    scanfunctions(path; public_only=false, module_name="")

Parse Julia source without loading the target package and return structured
function, method, argument, keyword, default, return-annotation, visibility,
documentation, and source-span metadata.

When `path` is a directory, all `.jl` files below it are scanned in stable
lexicographic order.
`module_name` defaults to the nearest `Project.toml` package name.
Files that omit their enclosing `module` declaration are assigned this prefix;
literal `include` nesting is not evaluated, so scan such an implementation file
separately with its full enclosing module name when necessary.

# Arguments

- `path`: Julia source file or directory to inspect.

# Keywords

- `public_only`: Whether to return only exported, declared-public, or explicitly documented functions.
- `module_name`: Module prefix to use instead of the nearest project name.

# Returns

A vector of `FunctionSpec` records grouped by qualified function name.

# Examples

```julia
import DocumentFunction

specs = DocumentFunction.scanfunctions("src"; public_only=true)
all(spec -> !isempty(spec.methods), specs)
```
"""
function scanfunctions(
	path::AbstractString;
	public_only::Bool=false,
	module_name::AbstractString="",
)::Vector{FunctionSpec}
	files::Vector{String} = _source_files(path)
	inferred_module::String = isempty(module_name) ? _project_name(path) : String(module_name)
	modules::Vector{String} = isempty(inferred_module) ? String[] : [inferred_module]
	definitions::Vector{_FunctionDefinition} = _FunctionDefinition[]
	exported::Set{String} = Set{String}()
	public_names::Set{String} = Set{String}()

	for file::String in files
		file_definitions::Vector{_FunctionDefinition}, file_exports::Set{String}, file_public::Set{String} = _scan_file(file, modules)
		append!(definitions, file_definitions)
		union!(exported, file_exports)
		union!(public_names, file_public)
	end

	functions::Vector{FunctionSpec} = _group_definitions(definitions, exported, public_names)
	if public_only
		return filter(_included_public_function, functions)
	end
	return functions
end

function _included_public_function(spec::FunctionSpec)::Bool
	return spec.is_public || !isnothing(spec.existing_doc)
end

function _path_key(path::AbstractString)::String
	resolved::String = normpath(abspath(path))
	return Sys.iswindows() ? lowercase(resolved) : resolved
end

function _matches_runtime_method(
	method::MethodSpec,
	runtime_methods::Vector{Method},
)::Bool
	method_path::String = _path_key(method.source.path)
	return any(runtime_methods) do runtime_method::Method
		runtime_path::String = String(runtime_method.file)
		if !isfile(runtime_path) || _path_key(runtime_path) != method_path
			return false
		end
		runtime_line::Int = Int(runtime_method.line)
		return method.source.first_line <= runtime_line <= method.source.last_line
	end
end

"""
    functionspec(f)

Locate and statically inspect the source-defined methods of a loaded Julia
function.

Use [`scanfunctions`](@ref) directly when the package should not be loaded or
when inspecting callable objects and generated methods whose source binding
cannot be identified reliably.

# Arguments

- `f`: Loaded callable whose source-defined methods should be located.

# Returns

A `FunctionSpec` containing the matching source definitions.
"""
function functionspec(f::Any)::FunctionSpec
	runtime_methods::Vector{Method} = collect(methods(f))
	if isempty(runtime_methods)
		throw(ArgumentError("the supplied callable has no methods with inspectable source"))
	end
	target_name::String = string(first(runtime_methods).name)
	runtime_module::Module = first(runtime_methods).module
	runtime_name::Symbol = first(runtime_methods).name
	target_module::String = string(runtime_module)
	files::Vector{String} = unique([
		String(method.file)
		for method::Method in runtime_methods
		if isfile(String(method.file))
	])
	candidates::Vector{FunctionSpec} = FunctionSpec[]
	for file::String in files
		append!(candidates, scanfunctions(file; module_name=target_module))
	end
	matches::Vector{FunctionSpec} = filter(candidates) do spec::FunctionSpec
		return _last_binding_component(spec.qualified_name) == target_name &&
			any(method::MethodSpec -> _matches_runtime_method(method, runtime_methods), spec.methods)
	end
	if isempty(matches)
		throw(ArgumentError("no statically identifiable source definition was found for $(target_module).$(target_name)"))
	end
	methods_found::Vector{MethodSpec} = MethodSpec[]
	for spec::FunctionSpec in matches
		append!(methods_found, filter(
			method::MethodSpec -> _matches_runtime_method(method, runtime_methods),
			spec.methods,
		))
	end
	doc_source::Union{Nothing, FunctionSpec} = nothing
	for spec::FunctionSpec in matches
		if !isnothing(spec.existing_doc)
			doc_source = spec
			break
		end
	end
	existing_doc::Union{Nothing, String} = isnothing(doc_source) ? nothing : doc_source.existing_doc
	doc_span::Union{Nothing, SourceSpan} = isnothing(doc_source) ? nothing : doc_source.doc_span
	hash_input::String = join([method.source_text for method::MethodSpec in methods_found], "\n\n")
	return FunctionSpec(
		"$(target_module).$(target_name)",
		methods_found,
		Base.isexported(runtime_module, runtime_name),
		Base.ispublic(runtime_module, runtime_name),
		existing_doc,
		doc_span,
		_source_hash(hash_input),
	)
end

"""
    scan(path; kwargs...)

Alias for [`scanfunctions`](@ref) for concise authoring scripts.

# Arguments

- `path`: Julia source file or directory to inspect.

# Keywords

- `kwargs`: Keyword arguments forwarded to `scanfunctions`.

# Returns

A vector of `FunctionSpec` records.
"""
function scan(path::AbstractString; kwargs...)::Vector{FunctionSpec}
	return scanfunctions(path; kwargs...)
end
