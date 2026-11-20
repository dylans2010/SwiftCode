---
name: agent-progress-reporting
description: "Report progress on long tasks with concise, decision-relevant updates."
category: Agent Behavior
tags: [progress, reporting, communication]
tools: [system_asset_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Progress Reporting

Report progress on long tasks with concise, decision-relevant updates.

## When to use this skill
- The user asks for work involving: progress, reporting, communication.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Share a short plan at the start.
2. Post updates at milestones, not every step.
3. Lead updates with status and any blocker.
4. Include evidence (tests, builds) for completed parts.
5. End with a summary of changes, verification and open items.

## Rules
- Brevity over narration.
- Never hide failures.

## Verification
- [ ] User can see status at a glance.
- [ ] Final report matches the work.

## Avoid
- Walls of text.
- Silent long stretches.

## Recommended SwiftCode tools
- `system_asset_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
