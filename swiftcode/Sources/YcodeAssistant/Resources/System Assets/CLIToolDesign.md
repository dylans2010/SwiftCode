# Command-Line Tool Design

<!-- system-index-depends: BuildAndTesting.md -->

A command-line tool is a contract with its user: predictable input,
predictable output, and a nonzero exit code when something fails. This
asset covers how Assist designs CLI tools that behave well in scripts.

## When to retrieve

- The user is building a command-line tool or adding a CLI to an app.
- A CLI's output, exit codes, or argument handling needs review.
- A script around the tool is fragile and the tool is the cause.

## Interface rules

- Arguments are explicit and documented. Every flag has a name, a
  purpose, and a default, and the help text states all three.
- Positional arguments are few and ordered by importance. Anything
  optional is a flag, not a positional.
- Output goes to stdout; diagnostics and errors go to stderr. Mixing
  them breaks every pipe the tool will ever be used in.
- Machine-readable output (JSON or a stable line format) is a first-class
  mode, not an afterthought, when the tool will be scripted.
- Exit codes are meaningful: zero for success, distinct nonzero codes
  for distinct failure kinds, and never zero on failure.

## Behavior rules

- The tool is silent on success unless asked to be verbose. Chatty
  success output breaks scripts that parse stdout.
- Errors are specific: what failed, which input caused it, and what the
  user can do. A bare "error" is not an error message.
- The tool never asks interactive questions when stdin is not a terminal,
  unless explicitly told to. Scripts cannot answer prompts.
- Destructive actions require an explicit flag, and a dry-run mode shows
  what would happen without doing it.
- The tool handles signals and partial output gracefully. A killed tool
  must not leave a half-written file in place.

## Testing rules

- Test the help text, the version output, and the exit codes, not just
  the happy path.
- Test with piped input and output, not just a terminal.
- Test failure modes: missing files, bad arguments, unwritable output,
  and interrupted runs.
- Keep the tool's core logic separate from argument parsing so both can
  be tested independently.

## Common mistakes

- Printing progress to stdout instead of stderr.
- Exiting zero after a failure because an error was caught and ignored.
- Requiring interactive confirmation in a non-interactive context.
- Changing output format between versions without a versioned flag.

## Cross-references

- Build and testing: `BuildAndTesting.md`
- Error handling: `ErrorHandling.md`
- File operations: `FileOperations.md`

## Limits

- Assist designs the interface and behavior. It does not choose a
  specific argument-parsing library for the user; it describes the
  contract any library must satisfy.
