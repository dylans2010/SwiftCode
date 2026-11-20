---
name: server-side-swift-vapor
description: "Build server-side Swift services with Vapor: routes, middleware, Fluent and tests."
category: Backend
tags: [vapor, server-side swift, backend]
tools: [swiftpm_describe_package, swiftpm_build_target]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Server Side Swift Vapor

Build server-side Swift services with Vapor: routes, middleware, Fluent and tests.

## When to use this skill
- The user asks for work involving: vapor, server-side swift, backend.
- You are about to change code in the Backend area and want SwiftCode's standard workflow.

## Workflow
1. Organize routes in RouteCollections.
2. Validate requests with Content + Validatable.
3. Use Fluent migrations and async queries.
4. Write XCTVapor tests for endpoints.

## Rules
- Config via environment.
- No blocking calls on event loops.

## Verification
- [ ] Endpoint tests pass.
- [ ] Migrations reversible.

## Avoid
- Blocking I/O in handlers.
- Secrets in code.

## Recommended SwiftCode tools
- `swiftpm_describe_package`
- `swiftpm_build_target`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
