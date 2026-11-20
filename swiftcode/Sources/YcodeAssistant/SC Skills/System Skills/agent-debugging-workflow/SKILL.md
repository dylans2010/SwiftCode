---
name: agent-debugging-workflow
description: "Debug systematically as an agent: reproduce, isolate, hypothesize, fix, verify."
category: Agent Behavior
tags: [debugging, agent, root cause]
tools: [swiftpm_run_filtered_tests, git_log_pickaxe, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Debugging Workflow

Debug systematically as an agent: reproduce, isolate, hypothesize, fix, verify.

## When to use this skill
- The user asks for work involving: debugging, agent, root cause.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Reproduce with a command or test.
2. Read error output fully.
3. Form one hypothesis at a time and test it.
4. Fix the root cause.
5. Verify with the repro and full tests.

## Rules
- Stop and report if stuck after 3 hypotheses.
- Never mask errors.

## Verification
- [ ] Repro now passes.
- [ ] Explanation of cause given.

## Avoid
- Random changes.
- Silencing errors.

## Recommended SwiftCode tools
- `swiftpm_run_filtered_tests`
- `git_log_pickaxe`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
