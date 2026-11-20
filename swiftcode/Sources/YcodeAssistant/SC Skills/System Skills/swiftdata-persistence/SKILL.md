---
name: swiftdata-persistence
description: "Model and persist data with SwiftData: @Model, relationships, queries and migrations."
category: Data & Persistence
tags: [swiftdata, persistence, database]
tools: [scan_swiftdata_usage, swift_list_types]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftdata Persistence

Model and persist data with SwiftData: @Model, relationships, queries and migrations.

## When to use this skill
- The user asks for work involving: swiftdata, persistence, database.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Define @Model classes with explicit relationships and delete rules.
2. Create a ModelContainer at app start; inject modelContext via environment.
3. Use @Query with predicates and sort descriptors for views.
4. Do heavy writes in a background ModelActor.
5. Plan VersionedSchema and migration stages before shipping changes.

## Rules
- Never block the main actor with large fetches.
- Unique attributes for identifiers.

## Verification
- [ ] In-memory container tests pass.
- [ ] Migration tested from previous schema.

## Avoid
- Passing model objects across actors.
- Schema changes without migration.

## Recommended SwiftCode tools
- `scan_swiftdata_usage`
- `swift_list_types`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
