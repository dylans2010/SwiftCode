---
name: agent-verification-discipline
description: "Verify every change by building, testing and re-reading before reporting success."
category: Agent Behavior
tags: [verification, testing, quality]
tools: [swiftpm_build_target, swiftpm_run_filtered_tests, git_diff_stat_range]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Verification Discipline

Verify every change by building, testing and re-reading before reporting success.

## When to use this skill
- The user asks for work involving: verification, testing, quality.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. After editing, re-read the changed region.
2. Build the affected target.
3. Run targeted tests, then broader tests.
4. Review the diff for unintended changes.
5. Report exact commands and results.

## Rules
- No 'should work' claims.
- If verification is impossible, say so explicitly.

## Verification
- [ ] Build and tests pass.
- [ ] Diff contains only intended changes.

## Avoid
- Skipping tests for 'small' changes.
- Hiding failures.

## Recommended SwiftCode tools
- `swiftpm_build_target`
- `swiftpm_run_filtered_tests`
- `git_diff_stat_range`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
