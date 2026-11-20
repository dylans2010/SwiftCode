---
name: branching-strategy
description: "Choose and apply a branching strategy (trunk-based, GitFlow) consistently."
category: Git & Collaboration
tags: [branching, git workflow, trunk-based]
tools: [git_branch_overview, git_ahead_behind]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Branching Strategy

Choose and apply a branching strategy (trunk-based, GitFlow) consistently.

## When to use this skill
- The user asks for work involving: branching, git workflow, trunk-based.
- You are about to change code in the Git & Collaboration area and want SwiftCode's standard workflow.

## Workflow
1. Review current branches and activity.
2. Pick trunk-based for CI-heavy teams; release branches if needed.
3. Keep branches short-lived.
4. Delete merged branches.

## Rules
- Main always releasable.
- Protect main.

## Verification
- [ ] Stale branches cleaned.
- [ ] Policy documented.

## Avoid
- Long-lived feature branches.
- Direct pushes to protected branches.

## Recommended SwiftCode tools
- `git_branch_overview`
- `git_ahead_behind`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
