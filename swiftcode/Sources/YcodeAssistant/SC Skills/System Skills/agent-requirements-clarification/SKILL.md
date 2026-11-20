---
name: agent-requirements-clarification
description: "Clarify ambiguous requests efficiently before committing to an implementation."
category: Agent Behavior
tags: [clarification, requirements, agent]
tools: [system_asset_read, workspace_extension_stats]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Requirements Clarification

Clarify ambiguous requests efficiently before committing to an implementation.

## When to use this skill
- The user asks for work involving: clarification, requirements, agent.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Identify the ambiguities that change the outcome.
2. Resolve what you can from the code and context first.
3. Ask one focused question with concrete options when needed.
4. State the default you will use if there is no answer.
5. Record the decision in the plan.

## Rules
- Never ask what the code can tell you.
- Keep questions few and specific.

## Verification
- [ ] Every question was necessary.
- [ ] Decisions recorded.

## Avoid
- Long questionnaires.
- Building on unconfirmed assumptions.

## Recommended SwiftCode tools
- `system_asset_read`
- `workspace_extension_stats`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
