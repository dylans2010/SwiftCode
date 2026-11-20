---
name: data-export-import
description: "Implement user data export/import (JSON, CSV, files) safely and reversibly."
category: Data & Persistence
tags: [export, import, backup]
tools: [convert_json_text_to_csv, json_structure_validate]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Data Export Import

Implement user data export/import (JSON, CSV, files) safely and reversibly.

## When to use this skill
- The user asks for work involving: export, import, backup.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Define a versioned export format.
2. Export via FileDocument/Transferable or share sheet.
3. Validate imports fully before writing anything.
4. Make import transactional and report what was imported.
5. Round-trip test export→import.

## Rules
- Imports are untrusted input.
- Never lose existing data silently.

## Verification
- [ ] Round-trip preserves data.
- [ ] Malformed files rejected with messages.

## Avoid
- Partial imports on errors.
- Unversioned formats.

## Recommended SwiftCode tools
- `convert_json_text_to_csv`
- `json_structure_validate`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
