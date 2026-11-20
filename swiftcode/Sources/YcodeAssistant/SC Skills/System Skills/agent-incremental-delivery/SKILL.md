---
name: agent-incremental-delivery
description: "Deliver large tasks incrementally with checkpoints and status reporting."
category: Agent Behavior
tags: [delivery, checkpoints, progress]
tools: [git_staged_diff_stat, git_commit_count]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Incremental Delivery

Deliver large tasks incrementally with checkpoints and status reporting.

## When to use this skill
- The user asks for work involving: delivery, checkpoints, progress.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Split the task into shippable increments.
2. Verify and checkpoint each increment.
3. Report progress with what is done and next.
4. Keep the main branch working.

## Rules
- Each increment builds.
- Communicate plan changes.

## Verification
- [ ] Every checkpoint verified.
- [ ] Final report complete.

## Avoid
- One giant unverified change.
- Silent scope changes.

## Recommended SwiftCode tools
- `git_staged_diff_stat`
- `git_commit_count`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
