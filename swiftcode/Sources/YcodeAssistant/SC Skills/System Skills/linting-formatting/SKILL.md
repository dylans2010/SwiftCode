---
name: linting-formatting
description: "Set up and apply SwiftLint/swift-format consistently."
category: Code Quality
tags: [lint, format, style]
tools: [swift_format_lint_check, swift_format_apply, scan_swiftlint_disables, scan_trailing_whitespace]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Linting Formatting

Set up and apply SwiftLint/swift-format consistently.

## When to use this skill
- The user asks for work involving: lint, format, style.
- You are about to change code in the Code Quality area and want SwiftCode's standard workflow.

## Workflow
1. Detect existing config (.swiftlint.yml/.swift-format).
2. Run lint to get a baseline.
3. Fix autocorrectable issues with swift_format_apply on touched files.
4. Add CI lint step.
5. Justify any disable comments.

## Rules
- Format only files you touch unless asked.
- Config committed to repo.

## Verification
- [ ] Lint clean on changed files.
- [ ] CI enforces.

## Avoid
- Reformatting the entire repo in a feature PR.
- Blanket disables.

## Recommended SwiftCode tools
- `swift_format_lint_check`
- `swift_format_apply`
- `scan_swiftlint_disables`
- `scan_trailing_whitespace`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
