---
name: shell-scripting-safety
description: "Write safe, portable shell scripts for build and automation tasks."
category: Build & Tooling
tags: [shell, bash, automation]
tools: [scan_process_launches, scan_process_launches]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Shell Scripting Safety

Write safe, portable shell scripts for build and automation tasks.

## When to use this skill
- The user asks for work involving: shell, bash, automation.
- You are about to change code in the Build & Tooling area and want SwiftCode's standard workflow.

## Workflow
1. Start with set -euo pipefail.
2. Quote all variables.
3. Use arrays for arguments.
4. Check for required tools upfront.

## Rules
- Never eval untrusted input.
- Idempotent scripts.

## Verification
- [ ] shellcheck clean.
- [ ] Runs twice without harm.

## Avoid
- Unquoted $VAR.
- rm -rf with variables unchecked.

## Recommended SwiftCode tools
- `scan_process_launches`
- `scan_process_launches`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
