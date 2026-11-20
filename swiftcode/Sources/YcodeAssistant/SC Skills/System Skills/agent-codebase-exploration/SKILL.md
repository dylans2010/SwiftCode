---
name: agent-codebase-exploration
description: "Explore unfamiliar codebases quickly and build an accurate mental model."
category: Agent Behavior
tags: [exploration, codebase, onboarding]
tools: [workspace_extension_stats, swift_list_types, swift_list_imports, git_contributor_summary, readme_locate]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Agent Codebase Exploration

Explore unfamiliar codebases quickly and build an accurate mental model.

## When to use this skill
- The user asks for work involving: exploration, codebase, onboarding.
- You are about to change code in the Agent Behavior area and want SwiftCode's standard workflow.

## Workflow
1. Read README and package manifests.
2. Get language/size stats and directory sizes.
3. Outline key types and entry points.
4. Trace one feature end to end.
5. Write down findings before changing code.

## Rules
- Base conclusions on code, not names.
- Note uncertainties.

## Verification
- [ ] Can explain architecture in a paragraph.
- [ ] Entry points identified.

## Avoid
- Changing code before understanding.
- Assuming from file names.

## Recommended SwiftCode tools
- `workspace_extension_stats`
- `swift_list_types`
- `swift_list_imports`
- `git_contributor_summary`
- `readme_locate`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
