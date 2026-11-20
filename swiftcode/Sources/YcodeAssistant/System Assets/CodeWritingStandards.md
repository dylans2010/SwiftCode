<!-- system-index-depends: SwiftUsage.md, ErrorHandling.md -->
# CodeWritingStandards — How to Write Code in SwiftCode

## Before writing
- Read the surrounding code, its tests and its callers (`swift_file_outline`, `swift_symbol_references`).
- Reuse existing types, helpers and patterns; do not introduce a second way of doing the same thing.
- Confirm the target platform, Swift language mode and minimum OS version from the package or project settings.

## While writing
- Make the smallest complete change that solves the problem. No placeholders, mock data, `fatalError("TODO")` or fake implementations.
- Follow the Swift API Design Guidelines: clear names at the call site, lowerCamelCase members, UpperCamelCase types.
- Prefer value types, `let`, and enums for finite state. Make invalid states unrepresentable.
- Handle errors explicitly: typed errors conforming to `LocalizedError`, no empty `catch`, no `try!` in production paths.
- Avoid force unwraps and force casts; use `guard let` with early exit.
- Concurrency: UI state on `@MainActor`, shared mutable state in actors, structured concurrency (`async let`, task groups), honor cancellation. No `@unchecked Sendable` to silence warnings.
- Security: no secrets in source, Keychain for credentials, CryptoKit for cryptography, HTTPS only, parameterized SQL, fixed argument arrays for processes.
- Keep functions short (under ~50 lines) and nesting shallow; extract helpers with intention-revealing names.
- Comments explain why, not what. Document every public API with `///`.

## After writing
- Re-read the diff for unintended changes, debug prints and leftover code.
- Build the affected target and fix every new error and warning.
- Add or update tests for the new behavior (see `TestingPlaybook.md`).
- Run the relevant scans (`scan_force_unwrap`, `scan_hardcoded_secrets`, `scan_print_statements`) on touched files.

## Editing safely
- Use structured edit tools (`code_replace`, `code_multi_edit`) instead of whole-file rewrites for small changes.
- For bulk edits, preview with `dry_run` first and back up with `file_backup_copy`.
- Never modify generated files, lockfiles or vendored code unless the task requires it.
