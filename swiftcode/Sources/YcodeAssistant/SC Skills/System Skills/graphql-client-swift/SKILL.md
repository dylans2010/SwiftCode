---
name: graphql-client-swift
description: "Consume GraphQL APIs from Swift with typed operations and error handling."
category: Networking
tags: [graphql, api, codable]
tools: [http_post_json, json_to_swift_codable]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Graphql Client Swift

Consume GraphQL APIs from Swift with typed operations and error handling.

## When to use this skill
- The user asks for work involving: graphql, api, codable.
- You are about to change code in the Networking area and want SwiftCode's standard workflow.

## Workflow
1. Write operations as .graphql documents.
2. POST {query, variables} and decode data/errors.
3. Treat partial data + errors explicitly.
4. Generate or hand-write Codable response types from real responses.
5. Cache normalized entities if needed.

## Rules
- Request only fields you use.
- Surface GraphQL errors to logs.

## Verification
- [ ] Operations tested against real schema responses.
- [ ] Errors handled.

## Avoid
- Querying everything.
- Ignoring the errors array.

## Recommended SwiftCode tools
- `http_post_json`
- `json_to_swift_codable`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
