---
name: core-data-stack
description: "Maintain Core Data stacks safely: contexts, concurrency and lightweight migration."
category: Data & Persistence
tags: [core data, persistence, migration]
tools: [scan_core_data_usage, scan_main_thread_checks]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Core Data Stack

Maintain Core Data stacks safely: contexts, concurrency and lightweight migration.

## When to use this skill
- The user asks for work involving: core data, persistence, migration.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Use NSPersistentContainer with viewContext for UI and newBackgroundContext for writes.
2. Wrap work in perform/performAndWait.
3. Enable automaticallyMergesChangesFromParent.
4. Version the model for every change; prefer lightweight migration.
5. Enable -com.apple.CoreData.ConcurrencyDebug 1 during development.

## Rules
- Objects never cross contexts; pass NSManagedObjectID.
- Save only when hasChanges.

## Verification
- [ ] Concurrency debug flag shows no violations.
- [ ] Migration from previous version succeeds.

## Avoid
- Using viewContext from background threads.
- Editing the model without a new version.

## Recommended SwiftCode tools
- `scan_core_data_usage`
- `scan_main_thread_checks`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
