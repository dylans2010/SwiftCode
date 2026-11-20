---
name: rest-api-design
description: "Design RESTful APIs with consistent resources, status codes and errors."
category: Backend
tags: [rest, api design, http]
tools: [http_get_request, json_validate]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Rest Api Design

Design RESTful APIs with consistent resources, status codes and errors.

## When to use this skill
- The user asks for work involving: rest, api design, http.
- You are about to change code in the Backend area and want SwiftCode's standard workflow.

## Workflow
1. Model resources and relationships as nouns.
2. Use correct methods and status codes.
3. Define a consistent error body.
4. Version and paginate.

## Rules
- Idempotent PUT/DELETE.
- Stable field names.

## Verification
- [ ] Contract tests pass.
- [ ] Docs updated.

## Avoid
- Verbs in URLs.
- 200 for errors.

## Recommended SwiftCode tools
- `http_get_request`
- `json_validate`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
