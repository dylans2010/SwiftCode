---
name: agent-task-planning
description: "Plan multi-step engineering tasks: clarify, decompose, execute, verify, report."
category: Agent Behavior
tags: [planning, agent, workflow]
tools: [tool_catalog_search, system_asset_search, workspace_extension_stats]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Task Planning

Plan multi-step engineering tasks: clarify, decompose, execute, verify, report.

## When to use this skill
- The user asks for work involving: planning, agent, workflow.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Restate the goal and success criteria.
2. Explore the codebase before deciding (read, search, outline).
3. Break work into ordered, verifiable steps.
4. Execute step by step, verifying each.
5. Report outcome, evidence and remaining risks.

## Rules
- Prefer the smallest change that solves the problem.
- Re-plan when facts change.

## Verification
- [ ] Every step has a check.
- [ ] Final report matches what was done.

## Avoid
- Coding before understanding.
- Claiming success without verification.

## Recommended SwiftCode tools
- `tool_catalog_search`
- `system_asset_search`
- `workspace_extension_stats`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
