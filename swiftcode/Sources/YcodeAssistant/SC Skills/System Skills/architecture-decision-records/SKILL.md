---
name: architecture-decision-records
description: "Record architecture decisions as ADRs with context, decision and consequences."
category: Documentation
tags: [adr, architecture, decisions]
tools: [file_create, workspace_find_by_glob]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Architecture Decision Records

Record architecture decisions as ADRs with context, decision and consequences.

## When to use this skill
- The user asks for work involving: adr, architecture, decisions.
- You are about to change code in the Documentation area and want SwiftCode's standard workflow.

## Workflow
1. Locate existing docs/adr directory or create one.
2. Number ADRs sequentially (0001-title.md).
3. Write Context, Decision, Status, Consequences, Alternatives.
4. Link related ADRs and superseded ones.
5. Keep each ADR under one page.

## Rules
- ADRs are immutable once accepted; supersede instead.
- Record the alternatives you rejected.

## Verification
- [ ] ADR index updated.
- [ ] Decision is traceable from code comments if relevant.

## Avoid
- Retroactive essays.
- Vague decisions.

## Recommended SwiftCode tools
- `file_create`
- `workspace_find_by_glob`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
