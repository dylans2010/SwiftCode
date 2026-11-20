---
name: git-history-investigation
description: "Investigate code history to understand why code exists."
category: Git & Collaboration
tags: [git history, blame, archaeology]
tools: [git_file_history, git_blame_authors, git_log_pickaxe, git_show_commit_summary]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Git History Investigation

Investigate code history to understand why code exists.

## When to use this skill
- The user asks for work involving: git history, blame, archaeology.
- You are about to change code in the Git & Collaboration area and want SwiftCode's standard workflow.

## Workflow
1. Find relevant lines with blame.
2. Read the commits and messages.
3. Use pickaxe to find introduction/removal.
4. Summarize the rationale.

## Rules
- Context before changing old code.
- Credit authors.

## Verification
- [ ] Rationale documented.
- [ ] Related issues found.

## Avoid
- Assuming old code is wrong.
- Blaming people.

## Recommended SwiftCode tools
- `git_file_history`
- `git_blame_authors`
- `git_log_pickaxe`
- `git_show_commit_summary`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
