---
name: agent-context-management
description: "Manage limited context: summarize, take notes and retrieve only what is needed."
category: Agent Behavior
tags: [context, memory, efficiency]
tools: [save_to_memory, system_asset_search, file_head_lines]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Context Management

Manage limited context: summarize, take notes and retrieve only what is needed.

## When to use this skill
- The user asks for work involving: context, memory, efficiency.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Keep a running task note with decisions and next steps.
2. Read file regions instead of whole files.
3. Summarize long outputs.
4. Retrieve guidance on demand with system_asset_search.

## Rules
- Record facts, not guesses.
- Drop stale context.

## Verification
- [ ] Can resume after interruption.
- [ ] No repeated reads.

## Avoid
- Dumping huge files into context.
- Losing track of decisions.

## Recommended SwiftCode tools
- `save_to_memory`
- `system_asset_search`
- `file_head_lines`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
