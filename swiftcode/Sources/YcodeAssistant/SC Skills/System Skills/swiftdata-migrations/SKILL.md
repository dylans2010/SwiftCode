---
name: swiftdata-migrations
description: "Plan and test SwiftData schema migrations with VersionedSchema."
category: Data & Persistence
tags: [swiftdata, migrations, schema]
tools: [scan_swiftdata_usage, swift_list_types]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftdata Migrations

Plan and test SwiftData schema migrations with VersionedSchema.

## When to use this skill
- The user asks for work involving: swiftdata, migrations, schema.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Snapshot the current schema as a VersionedSchema.
2. Define the new version and a SchemaMigrationPlan with lightweight or custom stages.
3. Write custom stage logic for data transforms.
4. Test migration from a store created with the old schema.
5. Ship schema and migration together.

## Rules
- Never change a shipped model without a migration.
- Back up before risky migrations.

## Verification
- [ ] Migration test from previous version passes.
- [ ] No data loss.

## Avoid
- Renaming properties without originalName.
- Untested custom stages.

## Recommended SwiftCode tools
- `scan_swiftdata_usage`
- `swift_list_types`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
