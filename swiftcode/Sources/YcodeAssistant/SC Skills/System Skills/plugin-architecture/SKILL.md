---
name: plugin-architecture
description: "Design extensible plugin/extension points with protocols and registries."
category: Architecture
tags: [plugins, extensibility, registry]
tools: [swift_list_protocols, swift_find_conformers]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Plugin Architecture

Design extensible plugin/extension points with protocols and registries.

## When to use this skill
- The user asks for work involving: plugins, extensibility, registry.
- You are about to change code in the Architecture area and want SwiftCode's standard workflow.

## Workflow
1. Define a small, versioned plugin protocol.
2. Register plugins in a registry with unique identifiers.
3. Isolate plugin failures so they cannot crash the host.
4. Expose capabilities and metadata for discovery.
5. Document the contract and provide a sample plugin.

## Rules
- Stable contract, minimal surface.
- Host stays in control of lifecycle.

## Verification
- [ ] Sample plugin loads and runs.
- [ ] Faulty plugin is contained.

## Avoid
- Leaking host internals to plugins.
- Unversioned contracts.

## Recommended SwiftCode tools
- `swift_list_protocols`
- `swift_find_conformers`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
