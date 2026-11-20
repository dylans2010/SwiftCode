---
name: technical-specification-writing
description: "Write technical specs: problem, goals, design, alternatives, risks and rollout."
category: Product
tags: [spec, design doc, planning]
tools: [markdown_toc, file_create]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Technical Specification Writing

Write technical specs: problem, goals, design, alternatives, risks and rollout.

## When to use this skill
- The user asks for work involving: spec, design doc, planning.
- You are about to change code in the Product area and want SwiftCode's standard workflow.

## Workflow
1. State problem and goals/non-goals.
2. Describe the design with diagrams/interfaces.
3. List alternatives considered.
4. Cover risks, testing and rollout.

## Rules
- Specs are reviewable in 15 minutes.
- Decisions explicit.

## Verification
- [ ] Reviewers sign off.
- [ ] Open questions resolved.

## Avoid
- Implementation dumps.
- Missing non-goals.

## Recommended SwiftCode tools
- `markdown_toc`
- `file_create`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
