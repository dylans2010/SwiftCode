---
name: logging-observability
description: "Add structured logging, signposts and metrics using unified logging."
category: Debugging
tags: [logging, os_log, observability]
tools: [scan_logger_usage, scan_print_statements, scan_nslog_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Logging Observability

Add structured logging, signposts and metrics using unified logging.

## When to use this skill
- The user asks for work involving: logging, os_log, observability.
- You are about to change code in the Debugging area and want SwiftCode's standard workflow.

## Workflow
1. Create Logger instances per subsystem/category.
2. Log at correct levels (debug/info/notice/error/fault).
3. Mark dynamic values with privacy: .private/.public.
4. Add OSSignposter intervals for performance.
5. Remove print/NSLog.

## Rules
- No secrets in logs.
- Logs actionable.

## Verification
- [ ] Console filters by subsystem work.
- [ ] Signposts visible in Instruments.

## Avoid
- Logging everything at error level.
- String interpolation without privacy.

## Recommended SwiftCode tools
- `scan_logger_usage`
- `scan_print_statements`
- `scan_nslog_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
