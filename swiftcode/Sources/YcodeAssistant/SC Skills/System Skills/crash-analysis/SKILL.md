---
name: crash-analysis
description: "Symbolicate and analyze crash reports to find root causes."
category: Debugging
tags: [crash, symbolication, stack trace]
tools: [file_read, git_log_pickaxe, scan_force_unwrap]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Crash Analysis

Symbolicate and analyze crash reports to find root causes.

## When to use this skill
- The user asks for work involving: crash, symbolication, stack trace.
- You are about to change code in the Debugging area and want SwiftCode's standard workflow.

## Workflow
1. Get the crash report and matching dSYM.
2. Symbolicate with atos/Xcode Organizer.
3. Read the crashing thread top frames and exception type.
4. Map to source and reproduce with a test.
5. Fix and monitor.

## Rules
- Never guess from a non-symbolicated report.
- Check EXC_BAD_ACCESS for concurrency issues.

## Verification
- [ ] Repro test exists.
- [ ] Crash rate drops after release.

## Avoid
- Wrapping in try? to hide crashes.
- Ignoring background thread frames.

## Recommended SwiftCode tools
- `file_read`
- `git_log_pickaxe`
- `scan_force_unwrap`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
