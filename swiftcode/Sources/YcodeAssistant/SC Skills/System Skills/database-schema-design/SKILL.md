---
name: database-schema-design
description: "Design relational schemas with constraints, indexes and migrations."
category: Backend
tags: [database, schema, sql]
tools: [scan_sql_string_interpolation, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Database Schema Design

Design relational schemas with constraints, indexes and migrations.

## When to use this skill
- The user asks for work involving: database, schema, sql.
- You are about to change code in the Backend area and want SwiftCode's standard workflow.

## Workflow
1. Model entities and relationships.
2. Add primary/foreign keys, NOT NULL and unique constraints.
3. Index query patterns.
4. Write forward-only migrations.

## Rules
- Normalize first; denormalize with evidence.
- Constraints in the DB, not only app.

## Verification
- [ ] Migrations run on fresh and existing DBs.
- [ ] Query plans use indexes.

## Avoid
- Nullable everything.
- Schema changes by hand in prod.

## Recommended SwiftCode tools
- `scan_sql_string_interpolation`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
