---
name: swift-docs-tutorials
description: "Write step-by-step tutorials and how-to guides for Swift libraries."
category: Documentation
tags: [tutorials, how-to, docc]
tools: [swift_list_public_api, markdown_toc]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Docs Tutorials

Write step-by-step tutorials and how-to guides for Swift libraries.

## When to use this skill
- The user asks for work involving: tutorials, how-to, docc.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. Define the reader and the outcome of the tutorial.
2. Break it into short steps, each with code that compiles.
3. Show expected results after each step.
4. Use DocC tutorial format or Markdown with clear headings.
5. Test every step from a clean project.

## Rules
- Every snippet runs.
- One concept per step.

## Verification
- [ ] Fresh-project walkthrough succeeds.
- [ ] Links resolve.

## Avoid
- Skipping setup steps.
- Out-of-date APIs.

## Recommended SwiftCode tools
- `swift_list_public_api`
- `markdown_toc`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
