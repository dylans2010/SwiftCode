---
name: file-storage-sandbox
description: "Store files correctly in the app sandbox with protection and backups considered."
category: Data & Persistence
tags: [files, sandbox, file protection]
tools: [scan_file_manager_mutations, scan_file_protection]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# File Storage Sandbox

Store files correctly in the app sandbox with protection and backups considered.

## When to use this skill
- The user asks for work involving: files, sandbox, file protection.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Pick directory by purpose: Documents (user), Application Support (app data), Caches (re-creatable), tmp.
2. Write atomically and with .completeFileProtection for sensitive data.
3. Exclude large re-downloadable data from backups.
4. Use security-scoped bookmarks for user-chosen files on macOS.
5. Handle disk-full and permission errors.

## Rules
- Never hardcode absolute paths.
- Clean up temporary files.

## Verification
- [ ] Data survives relaunch.
- [ ] Sensitive files protected.

## Avoid
- Storing caches in Documents.
- Ignoring write errors.

## Recommended SwiftCode tools
- `scan_file_manager_mutations`
- `scan_file_protection`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
