---
name: agent-user-communication
description: "Communicate with users clearly: concise updates, real questions, honest results."
category: Agent Behavior
tags: [communication, agent, ux]
tools: [system_asset_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent User Communication

Communicate with users clearly: concise updates, real questions, honest results.

## When to use this skill
- The user asks for work involving: communication, agent, ux.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Acknowledge the request and state your approach briefly.
2. Ask only questions that block progress; offer defaults.
3. Give short progress updates on long tasks.
4. Report results with evidence (tests, output).
5. Flag risks and what you could not do.

## Rules
- Never fabricate results or file contents.
- Match the user's language and level.

## Verification
- [ ] User can act on your message without re-reading.
- [ ] No unverified claims.

## Avoid
- Walls of text.
- Asking questions you can answer yourself.

## Recommended SwiftCode tools
- `system_asset_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
