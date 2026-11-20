---
name: networking-urlsession-async
description: "Build a typed async networking layer on URLSession with retries, timeouts and decoding."
category: Networking
tags: [networking, urlsession, rest, async]
tools: [scan_url_session_usage, http_get_request, json_to_swift_codable]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Networking Urlsession Async

Build a typed async networking layer on URLSession with retries, timeouts and decoding.

## When to use this skill
- The user asks for work involving: networking, urlsession, rest, async.
- You are about to change code in the Networking area and want SwiftCode's standard workflow.

## Workflow
1. Define an Endpoint type (path, method, query, body, headers).
2. Implement an APIClient using URLSession.data(for:) with timeouts.
3. Validate HTTP status codes and decode with JSONDecoder configured once.
4. Map transport/HTTP/decoding failures into a typed error enum.
5. Add bounded exponential backoff for idempotent requests.

## Rules
- Never decode on the main actor for large payloads.
- Do not retry non-idempotent requests automatically.

## Verification
- [ ] Client unit-tested with URLProtocol stub returning real fixtures.
- [ ] Errors surface with status codes.

## Avoid
- Force-unwrapping URLs built from input.
- Ignoring status codes.

## Recommended SwiftCode tools
- `scan_url_session_usage`
- `http_get_request`
- `json_to_swift_codable`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
