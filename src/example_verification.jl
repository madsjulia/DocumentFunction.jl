struct _ProcessResult
	success::Bool
	timed_out::Bool
	stdout::String
	stderr::String
end

const _UNSAFE_EXAMPLE_PATTERNS = [
	r"\bccall\b",
	r"\beval\s*\(",
	r"\brun\s*\(",
	r"`[^`\n]+`",
	r"\bopen\s*\(",
	r"\bread\s*\(",
	r"\bwrite\s*\(",
	r"\brm\s*\(",
	r"\bmv\s*\(",
	r"\bcp\s*\(",
	r"\btouch\s*\(",
	r"\bmkdir\s*\(",
	r"\bmkpath\s*\(",
	r"\bdownload\b",
	r"\bDownloads\.",
	r"\bHTTP\.",
	r"\bSockets\.",
	r"\bLibGit2\.",
	r"\bPkg\.",
	r"\bENV\s*\[",
	r"\bBase\.include",
	r"\binclude\s*\(",
]

function _example_is_unsafe(code::AbstractString)::Bool
	return any(pattern::Regex -> occursin(pattern, code), _UNSAFE_EXAMPLE_PATTERNS)
end

function _example_runner(code::AbstractString)::String
	return """
result = Base.include_string(Main, $(repr(String(code))), "documentfunction-example")
if result !== nothing
	show(stdout, MIME("text/plain"), result)
	println()
end
"""
end

function _run_example_once(
	code::AbstractString,
	project::AbstractString,
	timeout_seconds::Float64,
)::_ProcessResult
	return mktempdir() do directory::String
		stdout_path::String = joinpath(directory, "stdout.txt")
		stderr_path::String = joinpath(directory, "stderr.txt")
		stdout_io::IOStream = open(stdout_path, "w")
		stderr_io::IOStream = open(stderr_path, "w")
		command::Cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(abspath(project)) -e $(_example_runner(code))`
		process::Base.Process = run(
			pipeline(ignorestatus(Cmd(command; dir=directory)), stdout=stdout_io, stderr=stderr_io);
			wait=false,
		)
		deadline::Float64 = time() + timeout_seconds
		while process_running(process) && time() < deadline
			sleep(0.05)
		end
		timed_out::Bool = process_running(process)
		if timed_out
			kill(process)
		end
		wait(process)
		close(stdout_io)
		close(stderr_io)
		stdout_text::String = chomp(_normalized_source(read(stdout_path, String)))
		stderr_text::String = chomp(_normalized_source(read(stderr_path, String)))
		return _ProcessResult(process.exitcode == 0 && !timed_out, timed_out, stdout_text, stderr_text)
	end
end

"""
    verifyexample(example; project=".", timeout_seconds=30, allow_unsafe=false)

Execute a complete example twice in fresh Julia processes with the target
project, a temporary working directory, and a timeout.

Stochastic examples must set their own fixed seed in `example.code`.

Common file, network, process, package-management, environment, and dynamic
evaluation operations detected by the preflight require `allow_unsafe=true`.
The preflight is not a security sandbox, so only trusted example source should
be executed.
The returned example is marked verified only when both executions succeed,
produce identical standard output without standard-error diagnostics, and
match `example.output` when expected output was provided.

# Arguments

- `example`: Complete example draft to execute.

# Keywords

- `project`: Julia project used by each isolated subprocess.
- `timeout_seconds`: Maximum duration allowed for each of the two executions.
- `allow_unsafe`: Whether potentially mutating, networked, dynamic, or process-launching code may run.

# Returns

An `ExampleVerification` containing the promoted example, reproducibility result, output, errors, and timeout state.
"""
function verifyexample(
	example::ExampleDraft;
	project::AbstractString=".",
	timeout_seconds::Real=30,
	allow_unsafe::Bool=false,
)::ExampleVerification
	if !example.complete
		throw(ArgumentError("cannot verify an example with unresolved placeholders"))
	end
	if timeout_seconds <= 0
		throw(ArgumentError("timeout_seconds must be positive"))
	end
	if !allow_unsafe && _example_is_unsafe(example.code)
		throw(ArgumentError("example contains an operation that requires allow_unsafe=true"))
	end
	first_result::_ProcessResult = _run_example_once(example.code, project, Float64(timeout_seconds))
	second_result::_ProcessResult = _run_example_once(example.code, project, Float64(timeout_seconds))
	deterministic::Bool = first_result.success && second_result.success &&
		first_result.stdout == second_result.stdout && first_result.stderr == second_result.stderr
	expected_matches::Bool = isnothing(example.output) || first_result.stdout == chomp(_normalized_source(example.output))
	stderr_empty::Bool = isempty(first_result.stderr) && isempty(second_result.stderr)
	success::Bool = deterministic && expected_matches && stderr_empty
	verified_example::ExampleDraft = ExampleDraft(
		example.code,
		first_result.stdout,
		example.complete,
		success,
		example.unresolved,
		:executed,
	)
	stderr_text::String = join(filter(value::String -> !isempty(value), unique([first_result.stderr, second_result.stderr])), "\n")
	return ExampleVerification(
		verified_example,
		success,
		deterministic,
		first_result.timed_out || second_result.timed_out,
		first_result.stdout,
		stderr_text,
	)
end

"""
    verifyexamples(draft; project=".", timeout_seconds=30, allow_unsafe=false)

Execute every complete example in a documentation draft twice and return a
copy of the draft containing the promoted verification results.

# Arguments

- `draft`: Documentation draft whose examples should be executed.

# Keywords

- `project`: Julia project used by each isolated subprocess.
- `timeout_seconds`: Maximum duration allowed for each execution.
- `allow_unsafe`: Whether potentially mutating, networked, dynamic, or process-launching code may run.

# Returns

A tuple containing the updated `DocumentationDraft` and each detailed
`ExampleVerification` result.
"""
function verifyexamples(
	draft::DocumentationDraft;
	project::AbstractString=".",
	timeout_seconds::Real=30,
	allow_unsafe::Bool=false,
)::Tuple{DocumentationDraft, Vector{ExampleVerification}}
	results::Vector{ExampleVerification} = [
		verifyexample(
			example;
			project=project,
			timeout_seconds=timeout_seconds,
			allow_unsafe=allow_unsafe,
		)
		for example::ExampleDraft in draft.examples
	]
	examples::Vector{ExampleDraft} = [result.example for result::ExampleVerification in results]
	warnings::Vector{String} = filter(
		warning::String -> !startswith(warning, "Example "),
		draft.warnings,
	)
	for (index::Int, result::ExampleVerification) in enumerate(results)
		if !result.success
			push!(warnings, "Example $(index) did not pass deterministic isolated verification.")
		end
	end
	verified_draft::DocumentationDraft = DocumentationDraft(
		draft.spec,
		draft.summary,
		draft.arguments,
		draft.keywords,
		draft.returns,
		examples,
		warnings,
	)
	return verified_draft, results
end
