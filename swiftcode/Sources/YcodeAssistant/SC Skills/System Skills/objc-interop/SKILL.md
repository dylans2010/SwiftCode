---
name: objc-interop
description: "Interoperate between Swift and Objective-C safely."
category: Swift Language
tags: [objective-c, interop, bridging]
tools: [scan_objc_attributes, scan_unsafe_pointers]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Objc Interop

Interoperate between Swift and Objective-C safely.

## When to use this skill
- The user asks for work involving: objective-c, interop, bridging.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Expose Swift with @objc only where needed.
2. Add nullability annotations to ObjC headers.
3. Use NS_SWIFT_NAME for better Swift names.
4. Avoid exposing Swift-only types to ObjC.

## Rules
- Keep bridging header minimal.
- Prefer Swift-native APIs internally.

## Verification
- [ ] Both languages compile without warnings.
- [ ] Nullability correct.

## Avoid
- @objcMembers everywhere.
- Implicitly unwrapped imports.

## Recommended SwiftCode tools
- `scan_objc_attributes`
- `scan_unsafe_pointers`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
