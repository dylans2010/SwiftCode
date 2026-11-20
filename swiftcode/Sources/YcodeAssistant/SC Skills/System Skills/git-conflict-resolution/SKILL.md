---
name: git-conflict-resolution
description: "Resolve merge and rebase conflicts safely while preserving both sides' intent."
category: Git & Collaboration
tags: [merge conflicts, rebase, git]
tools: [git_conflict_files, git_merge_base, git_show_file_at_revision]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Git Conflict Resolution

Resolve merge and rebase conflicts safely while preserving both sides' intent.

## When to use this skill
- The user asks for work involving: merge conflicts, rebase, git.
- You are about to change code in the Git & Collaboration area and want SwiftCode's standard workflow.

## Workflow
1. List conflicted files with git_conflict_files.
2. Inspect both versions and the merge base.
3. Combine intent, not just text.
4. Build and run tests after resolving.
5. Continue the merge/rebase and verify history.

## Rules
- Never pick a side blindly.
- Ask the author when intent is unclear.

## Verification
- [ ] No conflict markers remain (git_whitespace_check).
- [ ] Tests pass.

## Avoid
- Deleting the other side's work.
- Force pushing shared branches.

## Recommended SwiftCode tools
- `git_conflict_files`
- `git_merge_base`
- `git_show_file_at_revision`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
