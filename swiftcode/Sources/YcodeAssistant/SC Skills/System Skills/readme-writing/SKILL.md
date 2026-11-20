---
name: readme-writing
description: "Write a clear README: purpose, quick start, usage, configuration, contributing and license."
category: Documentation
tags: [readme_locate, documentation, onboarding]
tools: [readme_locate, swiftpm_describe_package, markdown_toc, workspace_extension_stats]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Readme Writing

Write a clear README: purpose, quick start, usage, configuration, contributing and license.

## When to use this skill
- The user asks for work involving: readme_locate, documentation, onboarding.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. Read the package/project structure to understand what it does.
2. Write a one-paragraph purpose statement and a feature list.
3. Provide copy-paste quick start commands that you verified.
4. Document configuration, environment variables and requirements.
5. Add a table of contents with markdown_toc for long READMEs.

## Rules
- Every command in the README must be tested.
- Lead with what the user can do.

## Verification
- [ ] Fresh clone follows README successfully.
- [ ] Links resolve (http_status_check).

## Avoid
- Marketing fluff.
- Instructions that only work on your machine.

## Recommended SwiftCode tools
- `readme_locate`
- `swiftpm_describe_package`
- `markdown_toc`
- `workspace_extension_stats`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
