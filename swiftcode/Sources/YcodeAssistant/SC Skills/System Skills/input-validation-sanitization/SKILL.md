---
name: input-validation-sanitization
description: "Validate and sanitize all untrusted input from users, files and networks."
category: Security
tags: [validation, sanitization, injection]
tools: [scan_sql_string_interpolation, scan_process_launches, scan_webview_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Input Validation Sanitization

Validate and sanitize all untrusted input from users, files and networks.

## When to use this skill
- The user asks for work involving: validation, sanitization, injection.
- You are about to change code in the Security area and want SwiftCode's standard workflow.

## Workflow
1. Enumerate entry points (forms, URLs, files, IPC, network).
2. Define allowed formats and lengths per field.
3. Parse into typed values at the boundary.
4. Escape for the output context (HTML, SQL, shell).
5. Test with malicious and boundary inputs.

## Rules
- Allowlist over denylist.
- Never pass input to a shell.

## Verification
- [ ] Fuzz/boundary tests pass.
- [ ] Injection scans clean.

## Avoid
- Trusting client-side checks.
- String-built commands.

## Recommended SwiftCode tools
- `scan_sql_string_interpolation`
- `scan_process_launches`
- `scan_webview_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
