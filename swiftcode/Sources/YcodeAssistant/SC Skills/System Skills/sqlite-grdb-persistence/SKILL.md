---
name: sqlite-grdb-persistence
description: "Use SQLite safely in Swift with parameterized queries and migrations."
category: Data & Persistence
tags: [sqlite, sql, database, migrations]
tools: [scan_sql_string_interpolation, file_read]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Sqlite Grdb Persistence

Use SQLite safely in Swift with parameterized queries and migrations.

## When to use this skill
- The user asks for work involving: sqlite, sql, database, migrations.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Choose a wrapper (GRDB or SQLite3 C API) and open the DB in Application Support.
2. Write ordered migrations.
3. Always bind parameters; never interpolate values.
4. Use WAL mode and transactions for batches.
5. Index columns used in WHERE/ORDER BY.

## Rules
- One writer connection.
- Back up before destructive migrations.

## Verification
- [ ] scan_sql_string_interpolation clean.
- [ ] Migration tests from empty and previous DB.

## Avoid
- String-built SQL.
- Schema changes without migrations.

## Recommended SwiftCode tools
- `scan_sql_string_interpolation`
- `file_read`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
