---
name: debugging-lldb
description: "Debug efficiently with LLDB, breakpoints and logging."
category: Debugging
tags: [debugging, lldb, breakpoints]
tools: [scan_print_statements, scan_logger_usage, file_tail_lines]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Debugging Lldb

Debug efficiently with LLDB, breakpoints and logging.

## When to use this skill
- The user asks for work involving: debugging, lldb, breakpoints.
- You are about to change code in the Debugging area and want SwiftCode's standard workflow.

## Workflow
1. Reproduce reliably and form a hypothesis.
2. Use breakpoints with conditions and actions instead of print.
3. Inspect with po/v/expression; use watchpoints for mutations.
4. Bisect with git if regression.
5. Remove temporary debug code.

## Rules
- Change one variable at a time.
- Write down findings.

## Verification
- [ ] Root cause identified and explained.
- [ ] Debug prints removed.

## Avoid
- Shotgun debugging.
- Leaving breakpoints in shared schemes.

## Recommended SwiftCode tools
- `scan_print_statements`
- `scan_logger_usage`
- `file_tail_lines`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
