---
name: dependency-injection-swift
description: "Wire dependencies with initializer injection, environment values and composition roots."
category: Architecture
tags: [dependency injection, composition root, environment]
tools: [scan_singletons, swift_generate_protocol_from_type]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Dependency Injection Swift

Wire dependencies with initializer injection, environment values and composition roots.

## When to use this skill
- The user asks for work involving: dependency injection, composition root, environment.
- You are about to change code in the Architecture area and want SwiftCode's standard workflow.

## Workflow
1. Find singletons with scan_singletons.
2. Introduce protocols at boundaries.
3. Construct the object graph in a composition root at app start.
4. Pass dependencies via initializers or SwiftUI Environment.
5. Provide test and preview configurations.

## Rules
- No service locators hidden in views.
- Defaults for production.

## Verification
- [ ] Previews run without network.
- [ ] Tests inject fakes.

## Avoid
- Singletons accessed deep in code.
- Optional dependencies everywhere.

## Recommended SwiftCode tools
- `scan_singletons`
- `swift_generate_protocol_from_type`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
