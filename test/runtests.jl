import DocumentFunction

expected = "Methods\n - `DocumentFunction.documentfunction(f::Function; location, maintext, argtext, keytext)`\nArguments\n - `f::Function`\nKeywords\n - `argtext`\n - `keytext`\n - `location`\n - `maintext`\n"

output = DocumentFunction.documentfunction(DocumentFunction.documentfunction; location=false)

@assert output == expected

:passed