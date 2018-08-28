import DocumentFunction

using Test

if VERSION >= v"0.6.0"
	expected = "**DocumentFunction.documentfunction**\n\nCreate function documentation\n\nMethods\n - `DocumentFunction.documentfunction(f::Function; location, maintext, argtext, keytext) in DocumentFunction`\nArguments\n - `f::Function` : Function to be documented\nKeywords\n - `argtext` : Dictionary with text for each argument\n - `keytext` : Dictionary with text for each keyword\n - `location` : Boolean to show/hide function location on the disk\n - `maintext` : Function description\n"
else
	expected = "**DocumentFunction.documentfunction**\n\nCreate function documentation\n\nMethods\n - `DocumentFunction.documentfunction(f::Function; location, maintext, argtext, keytext)`\nArguments\n - `f::Function` : Function to be documented\nKeywords\n - `argtext` : Dictionary with text for each argument\n - `keytext` : Dictionary with text for each keyword\n - `location` : Boolean to show/hide function location on the disk\n - `maintext` : Function description\n"
end

output = DocumentFunction.documentfunction(DocumentFunction.documentfunction;
	location=false,
	maintext="Create function documentation",
	argtext=Dict("f"=>"Function to be documented"),
	keytext=Dict("maintext"=>"Function description",
				 "argtext"=>"Dictionary with text for each argument",
				 "keytext"=>"Dictionary with text for each keyword",
				 "location"=>"Boolean to show/hide function location on the disk"))

DocumentFunction.documentfunction(DocumentFunction.stdoutcaptureon; location=true)
DocumentFunction.getfunctionkeywords(DocumentFunction.stdoutcaptureon)
DocumentFunction.getfunctionarguments(DocumentFunction.stdoutcaptureon)

@testset "Document" begin
    @test output == expected
    @test [] == DocumentFunction.getfunctionkeywords(DocumentFunction.stdoutcaptureon)
    @test [] == DocumentFunction.getfunctionarguments(DocumentFunction.stdoutcaptureon)
end

:passed
