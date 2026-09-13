Test.@testset "Offline checks and inventory" begin
	mktempdir() do directory::String
		write(joinpath(directory, "Project.toml"), "name = \"Sample\"\nuuid = \"4d3e7b4d-37b5-4823-a68a-f4f18e350bee\"\nversion = \"0.1.0\"\n")
		source_directory = joinpath(directory, "src")
		mkpath(source_directory)
		path = joinpath(source_directory, "Sample.jl")
		write(path, "module Sample\nexport documented\n\"\"\"Return the input.\n\n- `value`: Input value.\n\"\"\"\ndocumented(value::Int)::Int = value\nend\n")
		inventory_path = DocumentFunction.writeinventory(source_directory)
		Test.@test inventory_path == joinpath(directory, ".documentfunction.toml")
		Test.@test isempty(DocumentFunction.checkdocs(source_directory; require_parameters=true))

		write(path, replace(read(path, String), "= value" => "= value + 0"))
		issues = DocumentFunction.checkdocs(source_directory; require_parameters=true)
		Test.@test :stale in [issue.code for issue in issues]

		write(path, replace(read(path, String), "export documented" => "export documented, missing_doc") * "\nmissing_doc(x) = x\n")
		issues = DocumentFunction.checkdocs(source_directory)
		Test.@test :missing in [issue.code for issue in issues]
		Test.@test :untracked in [issue.code for issue in issues]
		Test.@test occursin("missing_doc", DocumentFunction.formatissues(issues; root=directory))
	end
end
