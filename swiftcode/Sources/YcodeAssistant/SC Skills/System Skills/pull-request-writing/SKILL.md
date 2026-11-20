---
name: pull-request-writing
description: "Write pull requests reviewers can approve quickly."
category: Git & Collaboration
tags: [pull request, pr description, review]
tools: [git_diff_stat_range, git_changed_files_since]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Pull Request Writing

Write pull requests reviewers can approve quickly.

## When to use this skill
- The user asks for work involving: pull request, pr description, review.
- You are about to change code in the Git & Collaboration area and want SwiftCode's standard workflow.

## Workflow
1. Summarize what and why in 2-3 sentences.
2. List notable changes and risks.
3. Explain how it was tested with commands.
4. Add screenshots for UI.
5. Keep PRs small; split when > 400 lines.

## Rules
- Link issues.
- Call out breaking changes.

## Verification
- [ ] Reviewer can reproduce tests.
- [ ] Description matches diff.

## Avoid
- Empty descriptions.
- Mixing refactors with features.

## Recommended SwiftCode tools
- `git_diff_stat_range`
- `git_changed_files_since`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
