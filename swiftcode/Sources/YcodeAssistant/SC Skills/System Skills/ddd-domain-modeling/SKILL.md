---
name: ddd-domain-modeling
description: "Model a domain with entities, value objects and aggregates in Swift."
category: Architecture
tags: [ddd, domain modeling, architecture]
tools: [swift_list_types, swift_list_structs]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Ddd Domain Modeling

Model a domain with entities, value objects and aggregates in Swift.

## When to use this skill
- The user asks for work involving: ddd, domain modeling, architecture.
- You are about to change code in the Architecture area and want SwiftCode's standard workflow.

## Workflow
1. Discover domain terms with the user and code.
2. Model value objects as immutable structs with validation.
3. Model entities with identity and aggregates with invariants enforced in one place.
4. Keep persistence and UI out of the domain module.
5. Test invariants directly.

## Rules
- Ubiquitous language in names.
- Invariants enforced in constructors/methods.

## Verification
- [ ] Domain tests pass without frameworks.
- [ ] No anemic models for core logic.

## Avoid
- Primitive obsession.
- Framework types in the domain.

## Recommended SwiftCode tools
- `swift_list_types`
- `swift_list_structs`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
