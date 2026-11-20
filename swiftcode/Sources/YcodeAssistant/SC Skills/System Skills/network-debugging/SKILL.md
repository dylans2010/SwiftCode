---
name: network-debugging
description: "Debug network issues with logging, proxies and reproducible requests."
category: Debugging
tags: [network debugging, http, proxy]
tools: [http_get_request, dns_lookup, http_status_check]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Network Debugging

Debug network issues with logging, proxies and reproducible requests.

## When to use this skill
- The user asks for work involving: network debugging, http, proxy.
- You are about to change code in the Debugging area and want SwiftCode's standard workflow.

## Workflow
1. Reproduce the failing request outside the app (http_get_request / curl equivalent).
2. Check DNS, TLS and status codes.
3. Log request/response metadata without secrets.
4. Compare headers and bodies between working and failing cases.
5. Fix and add a regression test with a stubbed transport.

## Rules
- Never log auth headers.
- Reproduce before fixing.

## Verification
- [ ] Failing case reproduced and fixed.
- [ ] Regression test added.

## Avoid
- Guessing at server behavior.
- Disabling TLS checks to debug.

## Recommended SwiftCode tools
- `http_get_request`
- `dns_lookup`
- `http_status_check`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
