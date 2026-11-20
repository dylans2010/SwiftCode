---
name: json-data-handling
description: "Inspect, validate, transform and query JSON data reliably."
category: Data & Persistence
tags: [json, data, transformation]
tools: [json_structure_validate, json_query, json_format, json_list_keys, json_format]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Json Data Handling

Inspect, validate, transform and query JSON data reliably.

## When to use this skill
- The user asks for work involving: json, data, transformation.
- You are about to change code in the Data & Persistence area and want SwiftCode's standard workflow.

## Workflow
1. Validate JSON with json_structure_validate.
2. Explore structure with json_list_keys.
3. Extract fields with json_query_path.
4. Convert with the convert_* tools.

## Rules
- Never hand-edit large JSON with regex.
- Keep key order stable for diffs.

## Verification
- [ ] Output validates.
- [ ] Round-trip preserves data.

## Avoid
- String concatenation to build JSON.
- Ignoring encoding.

## Recommended SwiftCode tools
- `json_structure_validate`
- `json_query`
- `json_format`
- `json_list_keys`
- `json_format`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
