# Agent guidance

## Scope

These instructions apply to the entire DocumentFunction repository.
Follow more specific instructions if a nested `AGENTS.md` is added later.

## First steps

Read `README.md`, `Project.toml`, CI workflows, and relevant source and tests before editing.
Inspect `git status --short` and preserve all unrelated or pre-existing changes.

## Julia style

- Use explicit package imports such as `import Random`.
- Do not introduce `using` when `import` can provide the required names.
- Qualify imported package names at call sites.
- Preserve an existing re-export or macro-loading exception only when the package API requires it.
- Prefer small functions with explicit inputs and outputs.
- Add types to public arguments and return values where consistent with the repository API.
- Preserve public APIs unless an API change is explicitly requested.
- Do not perform unrelated formatting or mechanical rewrites.

## Environment

Use a Julia version allowed by `Project.toml` and CI.
Run Julia without user startup-file customizations:

```powershell
julia --startup-file=no --project=.
```

Respect checked-in project and manifest files.
Do not replace sibling development packages with registry versions merely to simplify dependency resolution.

## Repository layout

- `src/` contains the active implementation.
- `test/` contains package tests.
- Consult `README.md` and existing examples or scripts for supported workflows.

Do not edit generated, vendored, legacy, result, or temporary directories unless the task explicitly places them in scope.

## Testing

Start with the narrowest relevant test.
Run the complete package suite with:

```powershell
julia --startup-file=no --project=. -e 'import Pkg; Pkg.test()'
```

Use fixed random seeds for stochastic tests and examples.
Separate environment or external-service failures from source regressions.

## Documentation

Update `README.md`, docstrings, and relevant examples when public behavior changes.
Keep examples consistent with the public API.
Write Markdown with one sentence per physical line when practical.

Treat source-extracted signatures, types, defaults, visibility, and declared return annotations as facts, but treat generated semantic descriptions as reviewable drafts.
Derive descriptions from existing documentation, tests, examples, implementation behavior, and call sites before using identifier-based templates.
Do not invent domain meaning, units, accepted values, side effects, array shapes, or return guarantees when the evidence is incomplete.
Keep unresolved descriptions as explicit `TODO` items and never auto-apply low-confidence prose.
Store accepted output as ordinary static Julia docstrings; package loading, tests, documentation builds, and CI must not require AI, credentials, or network access.
Render `jldoctest` examples only after they run successfully and deterministically in the target project.
Use repository-relative paths in generated evidence and do not publish local absolute paths.

## Safety and completion

Do not delete or overwrite datasets, model artifacts, cached results, figures, or user outputs without explicit authorization.
Do not commit, push, tag, publish, or deploy unless the user explicitly requests it.

Before completion, run the applicable tests and:

```powershell
git diff --check
git status --short
```

Report the checks run and any checks that were not run.

For documentation-authoring changes, also run:

```powershell
julia --startup-file=no --project=. scripts/document.jl --check --require-parameters
```
