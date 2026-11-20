---
name: agent-multi-file-refactors
description: "Execute large multi-file refactors safely with planning, batching and verification."
category: Agent Behavior
tags: [refactor, multi-file, agent]
tools: [swift_symbol_references, file_rename_identifier, swiftpm_build_target]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Multi File Refactors

Execute large multi-file refactors safely with planning, batching and verification.

## When to use this skill
- The user asks for work involving: refactor, multi-file, agent.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Map every affected symbol and file first.
2. Plan batches that each leave the project building.
3. Apply one batch, build, and run focused tests.
4. Commit or checkpoint after each green batch.
5. Run the full suite at the end.

## Rules
- Never leave the build broken between batches.
- Keep behavior identical.

## Verification
- [ ] Each batch builds.
- [ ] Full suite passes.

## Avoid
- One giant unverified change.
- Regex edits without symbol awareness.

## Recommended SwiftCode tools
- `swift_symbol_references`
- `file_rename_identifier`
- `swiftpm_build_target`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
