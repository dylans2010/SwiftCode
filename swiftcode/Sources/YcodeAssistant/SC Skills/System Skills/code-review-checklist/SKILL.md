---
name: code-review-checklist
description: "Review code for correctness, safety, tests, readability and performance."
category: Git & Collaboration
tags: [code review, pull requests, quality]
tools: [git_diff_stat_range, scan_force_unwrap, scan_hardcoded_secrets, swift_list_test_functions]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Code Review Checklist

Review code for correctness, safety, tests, readability and performance.

## When to use this skill
- The user asks for work involving: code review, pull requests, quality.
- You are about to change code in the Git & Collaboration area and want SwiftCode's standard workflow.

## Workflow
1. Read the description and diff stat.
2. Check correctness and edge cases first.
3. Check tests cover the change.
4. Run relevant scans on touched files.
5. Leave specific, actionable, kind comments with severity.

## Rules
- Distinguish blocking from nits.
- Review behavior, not style preferences.

## Verification
- [ ] Every blocking issue has a suggested fix.
- [ ] Tests reviewed.

## Avoid
- Rubber-stamping.
- Bikeshedding.

## Recommended SwiftCode tools
- `git_diff_stat_range`
- `scan_force_unwrap`
- `scan_hardcoded_secrets`
- `swift_list_test_functions`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
