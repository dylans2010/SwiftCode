---
name: agent-safe-mutations
description: "Make file and repository changes safely with backups, dry runs and minimal scope."
category: Agent Behavior
tags: [safety, mutations, backups]
tools: [file_backup_copy, file_regex_replace, git_untracked_files]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Safe Mutations

Make file and repository changes safely with backups, dry runs and minimal scope.

## When to use this skill
- The user asks for work involving: safety, mutations, backups.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Check git status before mutating.
2. Use dry_run options first for bulk edits.
3. Back up files before risky rewrites.
4. Keep changes scoped to the request.
5. Confirm destructive actions with the user.

## Rules
- Never delete without confirmation.
- Never force-push shared branches.

## Verification
- [ ] Changes reversible.
- [ ] Scope matches request.

## Avoid
- Repo-wide regex edits without review.
- Touching unrelated files.

## Recommended SwiftCode tools
- `file_backup_copy`
- `file_regex_replace`
- `git_untracked_files`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
