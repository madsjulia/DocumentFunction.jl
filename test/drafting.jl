Test.@testset "Description and example drafts" begin
	specs = DocumentFunction.scanfunctions(FIXTURE_PATH; module_name="FixtureModule")
	transform = findspec(specs, "transform_data")
	draft = DocumentFunction.draftdocumentation(
		transform;
		summary="Transform numeric values.",
		argtext=Dict(:data => "Numeric values supplied by the caller."),
		returntext="A scaled vector.",
		example_values=Dict(:data => "[1.0, 2.0]", :required => ":sample"),
	)
	Test.@test draft.summary.confidence == 1.0
	Test.@test draft.arguments[:data].provenance == :explicit
	Test.@test draft.arguments[:scale].provenance == :existing_doc
	Test.@test draft.keywords[:quiet].provenance == :existing_doc
	existing_return_draft = DocumentFunction.draftdocumentation(
		transform;
		summary="Transform numeric values.",
		example_values=Dict(:data => "[1.0, 2.0]", :required => ":sample"),
	)
	Test.@test existing_return_draft.returns.provenance == :existing_doc
	Test.@test existing_return_draft.returns.text == "A scaled vector."
	Test.@test only(draft.examples).complete
	Test.@test !only(draft.examples).verified
	Test.@test occursin("required=:sample", only(draft.examples).code)
	auto_container_example = DocumentFunction.exampledraft(
		transform;
		values=Dict(:required => ":sample"),
	)
	Test.@test occursin("transform_data([1.0]", auto_container_example.code)

	runtime_spec = DocumentFunction.functionspec(DocumentFunction.documentfunction)
	safe_example = DocumentFunction.exampledraft(
		runtime_spec;
		values=Dict(:f => "identity", :location => "false"),
	)
	Test.@test occursin("location=false", safe_example.code)
	Test.@test_throws ArgumentError DocumentFunction.exampledraft(runtime_spec; method_index=2)

	multiline_doc = """
    multiline(
        value::Int,
    )

Return the supplied value.
"""
	multiline_spec = DocumentFunction.FunctionSpec(
		"Sample.multiline",
		DocumentFunction.MethodSpec[],
		true,
		true,
		multiline_doc,
		nothing,
		"hash",
	)
	multiline_draft = DocumentFunction.draftdocumentation(multiline_spec; returntext="The supplied value.")
	Test.@test multiline_draft.summary.text == "Return the supplied value."
	overloaded = findspec(specs, "overloaded")
	overloaded_draft = DocumentFunction.draftdocumentation(
		overloaded;
		returntext="The supplied value.",
		example_values=Dict(:value => "1"),
	)
	Test.@test_throws ArgumentError DocumentFunction.docpatch(
		overloaded_draft;
		replace_existing=true,
		allow_unreviewed=true,
		allow_content_loss=true,
	)

	markdown = DocumentFunction.renderdocumentation(draft)
	Test.@test occursin("# Arguments", markdown)
	Test.@test occursin("`quiet::Bool=false`", markdown)
	Test.@test occursin("```julia", markdown)

	undocumented = findspec(specs, "undocumented")
	unresolved = DocumentFunction.draftdocumentation(undocumented)
	Test.@test unresolved.arguments[:x].provenance == :unresolved
	Test.@test occursin("TODO:", unresolved.arguments[:x].text)
	Test.@test DocumentFunction.needsreview(unresolved)

	escaped = DocumentFunction.draftdocumentation(
		undocumented;
		summary="Preserve \\paths, \$values, and \"\"\" delimiters.",
		argtext=Dict(:x => "First value.", :y => "Second value."),
		keytext=Dict(:flag => "Whether to return values.", :mode => "Output mode."),
		returntext="A tuple or `nothing`.",
		example_values=Dict(:x => "1", :flag => "true"),
	)
	docstring_source = DocumentFunction.renderdocstring(escaped)
	Test.@test Meta.parse("$(docstring_source)\nsample() = nothing") isa Expr
end

Test.@testset "Static docstring patches" begin
	mktempdir() do directory::String
		path = joinpath(directory, "sample.jl")
		write(path, "module Sample\nexport addone\nfunction addone(value::Int)::Int\n\treturn value + 1\nend\nend\n")
		spec = only(DocumentFunction.scanfunctions(path; module_name="Sample", public_only=true))
		draft = DocumentFunction.draftdocumentation(
			spec;
			summary="Add one to an integer.",
			argtext=Dict(:value => "Integer to increment."),
			returntext="The incremented integer.",
			example_values=Dict(:value => "1"),
		)
		Test.@test_throws ArgumentError DocumentFunction.docpatch(draft)
		reviewed_draft = DocumentFunction.draftdocumentation(
			spec;
			summary="Add one to an integer.",
			argtext=Dict(:value => "Integer to increment."),
			returntext="The incremented integer.",
			example_values=Dict(:value => "1"),
			example_output="2",
			example_verified=true,
		)
		patch = DocumentFunction.docpatch(reviewed_draft)
		Test.@test DocumentFunction.applypatch!(patch)
		updated = only(DocumentFunction.scanfunctions(path; module_name="Sample", public_only=true))
		Test.@test !isnothing(updated.existing_doc)
		Test.@test occursin("Add one to an integer.", updated.existing_doc)

		stale_patch = DocumentFunction.docpatch(
			DocumentFunction.draftdocumentation(
				updated;
				summary="Updated summary.",
				returntext="The incremented integer.",
				example_values=Dict(:value => "1"),
				example_output="2",
				example_verified=true,
			);
			replace_existing=true,
			allow_content_loss=true,
		)
		write(path, read(path, String) * "\n")
		Test.@test_throws ArgumentError DocumentFunction.applypatch!(stale_patch)
	end

	mktempdir() do directory::String
		path::String = joinpath(directory, "decorated.jl")
		write(path, "module Decorated\nexport addone\n@inline addone(value::Int)::Int = value + 1\nend\n")
		spec = only(DocumentFunction.scanfunctions(path; module_name="Decorated", public_only=true))
		draft = DocumentFunction.draftdocumentation(
			spec;
			summary="Add one to an integer.",
			argtext=Dict(:value => "Integer to increment."),
			returntext="The incremented integer.",
			example_values=Dict(:value => "1"),
			example_output="2",
			example_verified=true,
		)
		Test.@test_throws ArgumentError DocumentFunction.docpatch(draft)
	end
end

Test.@testset "Isolated example verification" begin
	example = DocumentFunction.ExampleDraft(
		"import DocumentFunction\nDocumentFunction.getfunctionkeywords(DocumentFunction.getfunctionmethods)",
		nothing,
		true,
		false,
		Symbol[],
		:test,
	)
	verification = DocumentFunction.verifyexample(example; project=dirname(@__DIR__), timeout_seconds=30)
	Test.@test verification.success
	Test.@test verification.deterministic
	Test.@test verification.example.verified
	Test.@test verification.stdout == "String[]"
	rendered_base = DocumentFunction.draftdocumentation(
		DocumentFunction.functionspec(DocumentFunction.getfunctionkeywords);
		returntext="Keyword strings.",
		example_values=Dict(:f => "identity"),
	)
	rendered_verified = DocumentFunction.DocumentationDraft(
		rendered_base.spec,
		rendered_base.summary,
		rendered_base.arguments,
		rendered_base.keywords,
		rendered_base.returns,
		[DocumentFunction.ExampleDraft("import DocumentFunction\nDocumentFunction.getfunctionkeywords(identity)", "String[]", true, true, Symbol[], :test)],
		String[],
	)
	rendered_markdown = DocumentFunction.renderdocumentation(rendered_verified)
	Test.@test occursin("# output", rendered_markdown)
	Test.@test !occursin("julia>", rendered_markdown)

	spec = DocumentFunction.functionspec(DocumentFunction.getfunctionkeywords)
	draft = DocumentFunction.draftdocumentation(
		spec;
		returntext="A vector of keyword strings.",
		example_values=Dict(:f => "identity"),
	)
	verified_draft, results = DocumentFunction.verifyexamples(
		draft;
		project=dirname(@__DIR__),
		timeout_seconds=30,
	)
	Test.@test only(results).success
	Test.@test only(verified_draft.examples).verified
	Test.@test !DocumentFunction.needsreview(verified_draft)

	unsafe = DocumentFunction.ExampleDraft("open(\"output.txt\", \"w\")", nothing, true, false, Symbol[], :test)
	Test.@test_throws ArgumentError DocumentFunction.verifyexample(unsafe; project=dirname(@__DIR__))
	stable_stderr = DocumentFunction.ExampleDraft("println(stderr, \"warning\")\n1", nothing, true, false, Symbol[], :test)
	stderr_verification = DocumentFunction.verifyexample(stable_stderr; project=dirname(@__DIR__))
	Test.@test !stderr_verification.success
	Test.@test !stderr_verification.example.verified

	slow = DocumentFunction.ExampleDraft("sleep(5)\ntrue", nothing, true, false, Symbol[], :test)
	timed_out = DocumentFunction.verifyexample(slow; project=dirname(@__DIR__), timeout_seconds=0.1)
	Test.@test !timed_out.success
	Test.@test timed_out.timed_out
end
