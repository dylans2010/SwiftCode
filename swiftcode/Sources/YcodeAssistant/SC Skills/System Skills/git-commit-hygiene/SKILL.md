---
name: git-commit-hygiene
description: "Write focused commits with clear messages and clean history."
category: Git & Collaboration
tags: [git, commits, messages]
tools: [git_staged_diff_stat, git_whitespace_check, git_last_commit]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Git Commit Hygiene

Write focused commits with clear messages and clean history.

## When to use this skill
- The user asks for work involving: git, commits, messages.
- You are about to change code in the Git & Collaboration area and want SwiftCode's standard workflow.

## Workflow
1. Review staged changes with git_staged_diff_stat.
2. Split unrelated changes into separate commits.
3. Write imperative subject ≤ 72 chars, body explaining why.
4. Run git_whitespace_check before committing.
5. Reference issues where relevant.

## Rules
- One logical change per commit.
- Never commit secrets or build artifacts.

## Verification
- [ ] Each commit builds.
- [ ] Messages explain why.

## Avoid
- 'fix stuff' messages.
- Committing generated noise.

## Recommended SwiftCode tools
- `git_staged_diff_stat`
- `git_whitespace_check`
- `git_last_commit`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
