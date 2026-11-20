---
name: csv-data-processing
description: "Parse, clean and convert CSV data correctly including quoting rules."
category: Data & Persistence
tags: [csv, data, parsing]
tools: [convert_csv_text_to_json, convert_json_text_to_csv, text_statistics]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Csv Data Processing

Parse, clean and convert CSV data correctly including quoting rules.

## When to use this skill
- The user asks for work involving: csv, data, parsing.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Detect delimiter and header row.
2. Parse with RFC 4180 quoting.
3. Validate column counts.
4. Convert to typed models or JSON.

## Rules
- Handle embedded commas/newlines.
- Preserve encoding.

## Verification
- [ ] Round-trip test.
- [ ] Malformed rows reported.

## Avoid
- split(separator: ",").
- Silently dropping rows.

## Recommended SwiftCode tools
- `convert_csv_text_to_json`
- `convert_json_text_to_csv`
- `text_statistics`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
