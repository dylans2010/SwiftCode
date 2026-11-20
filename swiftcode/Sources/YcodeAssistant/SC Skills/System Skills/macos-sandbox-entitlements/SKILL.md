---
name: macos-sandbox-entitlements
description: "Configure macOS App Sandbox, entitlements and file access properly."
category: Platform
tags: [macos, sandbox, project_entitlements]
tools: [project_entitlements, codesign_inspect, scan_file_manager_mutations]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Macos Sandbox Entitlements

Configure macOS App Sandbox, entitlements and file access properly.

## When to use this skill
- The user asks for work involving: macos, sandbox, project_entitlements.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. List current entitlements.
2. Enable only required sandbox capabilities.
3. Use NSOpenPanel and security-scoped bookmarks for user files.
4. Use XPC services for privileged helpers.
5. Verify with codesign_inspect.

## Rules
- Least privilege.
- Persist bookmarks, not paths.

## Verification
- [ ] App works with sandbox on.
- [ ] Entitlements minimal.

## Avoid
- Temporary exception entitlements.
- Disabling sandbox.

## Recommended SwiftCode tools
- `project_entitlements`
- `codesign_inspect`
- `scan_file_manager_mutations`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
