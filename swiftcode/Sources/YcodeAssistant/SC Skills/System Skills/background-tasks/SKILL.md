---
name: background-tasks
description: "Schedule background refresh and processing with BGTaskScheduler."
category: Platform
tags: [background tasks, bgtaskscheduler, refresh]
tools: [info_plist_audit, scan_timer_usage]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Background Tasks

Schedule background refresh and processing with BGTaskScheduler.

## When to use this skill
- The user asks for work involving: background tasks, bgtaskscheduler, refresh.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. Register identifiers in Info.plist.
2. Register handlers at launch.
3. Schedule requests with earliest begin dates.
4. Set expiration handlers and complete tasks.

## Rules
- Work is resumable.
- Always call setTaskCompleted.

## Verification
- [ ] Simulate launch with debugger command.
- [ ] Expiration handled.

## Avoid
- Long unbounded work.
- Forgetting completion.

## Recommended SwiftCode tools
- `info_plist_audit`
- `scan_timer_usage`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
