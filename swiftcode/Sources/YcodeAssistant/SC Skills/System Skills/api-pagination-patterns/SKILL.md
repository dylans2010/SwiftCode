---
name: api-pagination-patterns
description: "Implement cursor and offset pagination with infinite scrolling."
category: Networking
tags: [pagination, infinite scroll, api]
tools: [http_get_request, swift_list_swiftui_views]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Api Pagination Patterns

Implement cursor and offset pagination with infinite scrolling.

## When to use this skill
- The user asks for work involving: pagination, infinite scroll, api.
- You are about to change code in the Networking area and want SwiftCode's standard workflow.

## Workflow
1. Identify the API's pagination style (cursor, offset, Link headers).
2. Model page state (items, next cursor, isLoading, reachedEnd).
3. Trigger the next load when the last items appear.
4. Deduplicate items by id and handle errors with retry.
5. Support pull-to-refresh resetting state.

## Rules
- Never load the same page twice concurrently.
- Stop at the end.

## Verification
- [ ] Rapid scrolling loads each page once.
- [ ] Errors recover.

## Avoid
- Offset pagination for changing lists without dedupe.
- Unbounded memory growth.

## Recommended SwiftCode tools
- `http_get_request`
- `swift_list_swiftui_views`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
