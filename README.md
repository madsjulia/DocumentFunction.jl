# DocumentFunction

[![CI](https://github.com/madsjulia/DocumentFunction.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/madsjulia/DocumentFunction.jl/actions/workflows/CI.yml)
[![Coverage Status](https://coveralls.io/repos/madsjulia/DocumentFunction.jl/badge.svg?branch=master)](https://coveralls.io/r/madsjulia/DocumentFunction.jl?branch=master)

DocumentFunction extracts Julia function signatures, positional arguments, keywords, defaults, declared return annotations, visibility, source spans, and existing documentation without loading the target package.

It then produces reviewable documentation drafts, evidence bundles for Codex or another author, static Julia docstrings, and deterministic offline coverage and freshness checks.

It complements `Documenter.jl`: DocumentFunction helps authors create and maintain the source docstrings, while Documenter remains the renderer, cross-reference checker, doctest runner, and deployment layer.

The original `documentfunction`, `getfunctionmethods`, `getfunctionarguments`, and `getfunctionkeywords` APIs remain available for compatibility.

## Installation

```julia
import Pkg
Pkg.add("DocumentFunction")
```

## Source inspection

```julia
import DocumentFunction

specs = DocumentFunction.scanfunctions("src"; public_only=true)
spec = only(filter(item -> endswith(item.qualified_name, "scanfunctions"), specs))

for method in spec.methods
    println(method.signature)
    for parameter in method.parameters
        println(parameter.name, " ", parameter.type_text, " ", parameter.default_text)
    end
end
```

`scanfunctions` uses source syntax rather than rendered method strings, so keyword order, keyword defaults, required keywords, positional defaults, varargs, and declared return types remain available.

The static scanner does not execute `include` statements; an implementation file that omits its enclosing submodule declaration should be scanned separately with `module_name="Parent.Submodule"`.

A loaded function can be mapped back to its source with `functionspec`:

```julia
spec = DocumentFunction.functionspec(DocumentFunction.documentfunction)
```

## Automated descriptions

The offline draft generator keeps extracted facts separate from generated prose.

```julia
draft = DocumentFunction.draftdocumentation(
    spec;
    summary="Inspect Julia source and collect function metadata.",
    argtext=Dict(:path => "Source file or directory to inspect."),
    keytext=Dict(
        :public_only => "Whether to return only exported, public, or explicitly documented functions.",
        :module_name => "Module name to use instead of the nearest project name.",
    ),
    returntext="A vector of structured `FunctionSpec` records.",
    example_values=Dict(:path => "\"src\""),
)

println(DocumentFunction.renderdocstring(draft))
```

Descriptions are selected in this order:

1. Explicit text supplied by the caller.
2. Existing structured docstring text or literal legacy `argtext` and `keytext` entries.
3. Conservative name-and-type templates for well-understood parameters such as `quiet`, `rng`, `atol`, and `maxiter`.
4. An explicit `TODO` when the available evidence cannot establish the meaning.

Every `DescriptionDraft` records its confidence, provenance, evidence, and whether it needs review.

Names such as `x`, `filename`, or `lambda` are not treated as sufficient semantic evidence because their meaning changes across functions.

Here, “variable descriptions” means the public inputs in a function contract—positional arguments and keywords—not every local implementation variable.

Use `DocumentFunction.needsreview(draft)` before applying generated prose.

## Execution examples

`exampledraft` builds a conservative call from declared types, defaults, and caller-provided values:

```julia
example = DocumentFunction.exampledraft(
    spec;
    values=Dict(:path => "\"src\""),
)

println(example.code)
println(example.complete)
println(example.verified)

verification = DocumentFunction.verifyexample(
    example;
    project=".",
    timeout_seconds=30,
)

println(verification.success)
```

For a complete documentation draft, verify and promote every example in one step:

```julia
draft, results = DocumentFunction.verifyexamples(draft; project=".")
all(result -> result.success, results)
```

`complete=true` means that the template has no unresolved placeholders.

It does not mean the example was executed.

An authoring workflow should run the example in a fresh process with `--startup-file=no`, the target project, a temporary working directory, fixed random seeds where applicable, and a timeout.

Only stable examples with confirmed output should be rendered as `jldoctest`; unverified examples remain ordinary `julia` blocks.

The verifier rejects common file writes, network access, child processes, package-management calls, environment access, and dynamic evaluation unless `allow_unsafe=true` is explicit.

This preflight is a safety check, not an operating-system sandbox, so execute only example source you trust.

## Codex evidence bundles

`documentationcontext` combines the definition, signatures, existing docs, draft descriptions, and matching calls from tests, examples, or documentation:

```julia
context = DocumentFunction.documentationcontext(
    spec;
    root=pwd(),
    evidence_paths=["test", "examples", "docs"],
)

write("documentation-context.md", context)
```

The `julia-doc-author` Codex skill can use this bundle to draft semantic descriptions from implementation behavior, tests, examples, and call sites instead of guessing from identifiers.

DocumentFunction itself never calls an AI service, and package imports, tests, documentation builds, and CI remain network-free.

## Command-line workflow

The included authoring script supports incremental generation:

```powershell
# Draft missing public API documentation locally.
julia --startup-file=no --project=. scripts/document.jl --missing

# Give Codex evidence only for changed Julia files.
julia --startup-file=no --project=. scripts/document.jl --prompt --changed --output=documentation-context.md

# Draft one named API rather than the entire source tree.
julia --startup-file=no --project=. scripts/document.jl --draft --function=scanfunctions

# Run deterministic documentation checks in CI.
julia --startup-file=no --project=. scripts/document.jl --check --require-parameters

# Accept reviewed source hashes after docs and examples are verified.
julia --startup-file=no --project=. scripts/document.jl --baseline
```

The checked-in `.documentfunction.toml` inventory allows `--check` to report public functions whose implementations changed after their documentation was reviewed.

CI does not call AI or judge writing style.

## Applying static docstrings

`docpatch` creates a byte-addressed edit protected by the current file hash.

```julia
draft, results = DocumentFunction.verifyexamples(draft; project=".")
@assert all(result -> result.success, results)
@assert !DocumentFunction.needsreview(draft)
patch = DocumentFunction.docpatch(draft)
DocumentFunction.applypatch!(patch)
```

`docpatch` refuses drafts for which `needsreview(draft)` is true unless `allow_unreviewed=true` is explicitly requested for a provisional manual-review patch.

Existing documentation is replaced only when `replace_existing=true` is explicitly supplied to `docpatch`.

Because a structured draft cannot prove that it preserves every intentional paragraph, replacing any existing documentation also requires `allow_content_loss=true` after manual comparison.

The result is an ordinary Julia docstring stored in source control, so Julia help mode and external `Documenter.jl` both consume the same documentation without runtime generation.

## Legacy API

Existing packages can continue to generate their current Markdown while they migrate incrementally:

```julia
import DocumentFunction

text = DocumentFunction.documentfunction(
    DocumentFunction.documentfunction;
    location=false,
    maintext="Create function documentation.",
    argtext=Dict("f" => "Function to document."),
    keytext=Dict("location" => "Whether to include source locations."),
)

print(text)
```

New documentation should prefer static docstrings generated from `FunctionSpec` records.

## Projects

- [Mads.jl](https://github.com/madsjulia/Mads.jl)
- [SmartTensors](https://github.com/SmartTensors)
- [SmartML.jl](https://github.com/SmartTensors/SmartML.jl)
