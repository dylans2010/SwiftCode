---
name: swift-on-linux-portability
description: "Keep Swift packages portable to Linux."
category: Platform
tags: [linux, portability, foundation]
tools: [swift_list_imports, swift_list_imports, swiftpm_build_target]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift On Linux Portability

Keep Swift packages portable to Linux.

## When to use this skill
- The user asks for work involving: linux, portability, foundation.
- You are about to change code in the Platform area and want SwiftCode's standard workflow.

## Workflow
1. List imports of Apple-only frameworks.
2. Guard with #if canImport and provide alternatives.
3. Use FoundationEssentials/FoundationNetworking where needed.
4. Build and test on Linux CI.

## Rules
- Platform code isolated.
- No Darwin assumptions in core.

## Verification
- [ ] Linux build passes.
- [ ] Tests pass on both.

## Avoid
- Unconditional UIKit/AppKit imports.
- Assuming case-insensitive filesystems.

## Recommended SwiftCode tools
- `swift_list_imports`
- `swift_list_imports`
- `swiftpm_build_target`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
