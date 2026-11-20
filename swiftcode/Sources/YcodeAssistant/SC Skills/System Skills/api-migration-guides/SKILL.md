---
name: api-migration-guides
description: "Write migration guides for breaking API changes between versions."
category: Documentation
tags: [migration guide, breaking changes, semver]
tools: [git_changed_files_since, swift_list_public_api, semver_compare]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Api Migration Guides

Write migration guides for breaking API changes between versions.

## When to use this skill
- The user asks for work involving: migration guide, breaking changes, semver.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. List removed, renamed and changed public APIs between versions.
2. For each, show before/after code.
3. Explain why and provide deprecation timelines.
4. Offer mechanical steps (find/replace, fix-its).
5. Link from the changelog.

## Rules
- Every breaking change documented.
- Before/after examples compile.

## Verification
- [ ] Guide covers the full API diff.
- [ ] Reviewed by someone upgrading.

## Avoid
- Vague 'some APIs changed'.
- Missing removed symbols.

## Recommended SwiftCode tools
- `git_changed_files_since`
- `swift_list_public_api`
- `semver_compare`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
