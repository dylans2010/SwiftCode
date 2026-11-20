---
name: code-comments-guidelines
description: "Write comments that explain why, document invariants and stay accurate."
category: Documentation
tags: [comments, code quality, documentation]
tools: [scan_todo_fixme_markers, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Code Comments Guidelines

Write comments that explain why, document invariants and stay accurate.

## When to use this skill
- The user asks for work involving: comments, code quality, documentation.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. Prefer clear names over comments.
2. Comment intent, invariants, non-obvious tradeoffs and links to specs.
3. Use /// for API docs and // for implementation notes.
4. Delete commented-out code.
5. Convert TODOs into tracked issues.

## Rules
- Comments must change with code.
- Short and specific.

## Verification
- [ ] No stale or misleading comments in touched code.
- [ ] TODO count does not grow.

## Avoid
- Narrating each line.
- Leaving dead code commented out.

## Recommended SwiftCode tools
- `scan_todo_fixme_markers`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
