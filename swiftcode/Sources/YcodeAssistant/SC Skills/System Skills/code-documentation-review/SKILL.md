---
name: code-documentation-review
description: "Review and improve documentation quality across a module."
category: Documentation
tags: [documentation, review, quality]
tools: [swift_undocumented_public_api, markdown_toc, http_status_check]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Code Documentation Review

Review and improve documentation quality across a module.

## When to use this skill
- The user asks for work involving: documentation, review, quality.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. List undocumented public symbols.
2. Check README accuracy by running commands.
3. Verify links with http_status_check.
4. Fix gaps starting with most-used APIs.

## Rules
- Accuracy over volume.
- Examples must compile.

## Verification
- [ ] Coverage improved.
- [ ] No broken links.

## Avoid
- Auto-generated filler comments.
- Outdated examples.

## Recommended SwiftCode tools
- `swift_undocumented_public_api`
- `markdown_toc`
- `http_status_check`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
