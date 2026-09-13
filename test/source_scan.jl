const FIXTURE_PATH = joinpath(@__DIR__, "fixtures", "functions.jl")

function findspec(specs::Vector{DocumentFunction.FunctionSpec}, suffix::AbstractString)::DocumentFunction.FunctionSpec
	index::Int = findfirst(spec::DocumentFunction.FunctionSpec -> endswith(spec.qualified_name, suffix), specs)
	return specs[index]
end

Test.@testset "Static source scanning" begin
	specs = DocumentFunction.scanfunctions(FIXTURE_PATH; module_name="FixtureModule")
	transform = findspec(specs, "transform_data")
	Test.@test transform.qualified_name == "FixtureModule.transform_data"
	Test.@test transform.is_exported
	Test.@test transform.is_public
	Test.@test !isnothing(transform.existing_doc)
	Test.@test length(transform.methods) == 1

	method = only(transform.methods)
	Test.@test method.declared_return_type == "Vector{Float64}"
	arguments = filter(parameter -> parameter.kind == DocumentFunction.PositionalParameter, method.parameters)
	keywords = filter(parameter -> parameter.kind == DocumentFunction.KeywordParameter, method.parameters)
	Test.@test [parameter.name for parameter in arguments] == [:data, :scale]
	Test.@test arguments[1].type_text == "Vector{Float64}"
	Test.@test arguments[2].default_text == "1.0"
	Test.@test [parameter.name for parameter in keywords] == [:quiet, :label, :required, :kwargs]
	Test.@test keywords[1].default_text == "false"
	Test.@test keywords[2].default_text == "\"\""
	Test.@test keywords[3].required
	Test.@test keywords[4].variadic
	Test.@test !keywords[4].required

	passthrough = findspec(specs, "passthrough")
	Test.@test any(parameter -> parameter.variadic, only(passthrough.methods).parameters)
	Test.@test occursin("where", only(passthrough.methods).signature)

	type_marker = findspec(specs, "type_marker")
	anonymous = first(filter(parameter -> parameter.anonymous, only(type_marker.methods).parameters))
	Test.@test anonymous.type_text == "Type{T}"
	Test.@test anonymous.name == :_arg1
	type_marker_issues = filter(
		issue -> issue.qualified_name == type_marker.qualified_name,
		DocumentFunction.checkdocs(FIXTURE_PATH; require_parameters=true, module_name="FixtureModule"),
	)
	Test.@test !any(
		issue -> issue.code == :incomplete && occursin("_arg1", issue.message),
		type_marker_issues,
	)

	public_function = findspec(specs, "public_function")
	Test.@test !public_function.is_exported
	Test.@test public_function.is_public

	public_specs = DocumentFunction.scanfunctions(FIXTURE_PATH; module_name="FixtureModule", public_only=true)
	Test.@test Set(spec.qualified_name for spec in public_specs) == Set([
		"FixtureModule.NestedA.repeated",
		"FixtureModule.interface_function",
		"FixtureModule.interface_only",
		"FixtureModule.overloaded",
		"FixtureModule.passthrough",
		"FixtureModule.public_function",
		"FixtureModule.transform_data",
		"FixtureModule.type_marker",
		"FixtureModule.undocumented",
	])
	nested_a = findspec(specs, "NestedA.repeated")
	nested_b = findspec(specs, "NestedB.repeated")
	Test.@test nested_a.is_exported
	Test.@test !nested_b.is_exported
	overloaded = findspec(specs, "overloaded")
	Test.@test length(overloaded.methods) == 2
	Test.@test isnothing(overloaded.doc_span)
	Test.@test occursin("Required handling mode.", overloaded.existing_doc)
	overloaded_issues = filter(
		issue -> issue.qualified_name == overloaded.qualified_name && issue.code == :incomplete,
		DocumentFunction.checkdocs(FIXTURE_PATH; require_parameters=true, module_name="FixtureModule"),
	)
	Test.@test isempty(overloaded_issues)
	interface_function = findspec(specs, "interface_function")
	Test.@test length(interface_function.methods) == 1
	Test.@test occursin("extensible interface", interface_function.existing_doc)
	interface_only = findspec(specs, "interface_only")
	Test.@test isempty(interface_only.methods)
	Test.@test interface_only.is_exported
	Test.@test !isnothing(interface_only.existing_doc)

	runtime_spec = DocumentFunction.functionspec(DocumentFunction.documentfunction)
	Test.@test runtime_spec.qualified_name == "DocumentFunction.documentfunction"
	Test.@test runtime_spec.is_exported
	Test.@test runtime_spec.is_public
	Test.@test any(parameter -> parameter.name == :location, only(runtime_spec.methods).parameters)
	context_spec = DocumentFunction.functionspec(DocumentFunction.scanfunctions)
	context = DocumentFunction.documentationcontext(context_spec; root=dirname(@__DIR__))
	Test.@test occursin("````text", context)
	Test.@test DocumentFunction._markdown_fence("```julia") == "````"

	sibling_spec = DocumentFunction.functionspec(ScanSiblingA.foo)
	Test.@test length(sibling_spec.methods) == 1
	Test.@test occursin("value::Int", only(sibling_spec.methods).signature)
end
