expected = "**DocumentFunction.documentfunction**\n\nCreate function documentation\n\nMethods:\n - `DocumentFunction.documentfunction(f::Function; location, maintext, argtext, keytext)`\nArguments:\n - `f` :: `Function` : Function to be documented\nKeywords:\n - `location` : Boolean to show/hide function location on the disk\n - `maintext` : General function description\n - `argtext` : Dictionary with text for each argument\n - `keytext` : Dictionary with text for each keyword\n"

output = DocumentFunction.documentfunction(DocumentFunction.documentfunction;
	location=false,
	maintext="Create function documentation",
	argtext=Dict("f"=>"Function to be documented"),
	keytext=Dict("maintext"=>"General function description",
				 "argtext"=>"Dictionary with text for each argument",
				 "keytext"=>"Dictionary with text for each keyword",
				 "location"=>"Boolean to show/hide function location on the disk"))

DocumentFunction.documentfunction(DocumentFunction.documentfunction; location=true)
noargfunction() = nothing

Test.@testset "Legacy API" begin
	Test.@test output == expected
	Test.@test [] == DocumentFunction.getfunctionkeywords(DocumentFunction.getfunctionmethods)
	Test.@test [] == DocumentFunction.getfunctionarguments(noargfunction)
	Test.@test ["x::Int64"] == DocumentFunction.getfunctionarguments(["sample(x::Int64)"])
	Test.@test ["quiet"] == DocumentFunction.getfunctionkeywords(["sample(x; quiet)"])
end
