---
name: agent-tool-selection
description: "Choose the right SwiftCode tool for each step and chain results efficiently."
category: Agent Behavior
tags: [tools, agent, efficiency]
tools: [tool_catalog_search, system_asset_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Tool Selection

Choose the right SwiftCode tool for each step and chain results efficiently.

## When to use this skill
- The user asks for work involving: tools, agent, efficiency.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Search the catalog for capability keywords.
2. Prefer read-only tools for discovery.
3. Use precise tools (outline, symbol references) before broad reads.
4. Chain outputs: search → read → edit → build → test.
5. Avoid repeating identical calls.

## Rules
- Never invent tool ids.
- Validate parameters against the schema.

## Verification
- [ ] Each tool call has a purpose.
- [ ] Mutations verified by a follow-up read/build.

## Avoid
- Using terminal for things tools do.
- Reading whole large files unnecessarily.

## Recommended SwiftCode tools
- `tool_catalog_search`
- `system_asset_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
