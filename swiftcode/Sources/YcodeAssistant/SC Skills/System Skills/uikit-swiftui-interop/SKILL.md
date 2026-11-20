---
name: uikit-swiftui-interop
description: "Bridge UIKit/AppKit and SwiftUI with representables and hosting controllers."
category: UI Design
tags: [uikit, appkit, representable, interop]
tools: [swift_list_types, scan_objc_attributes]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Uikit Swiftui Interop

Bridge UIKit/AppKit and SwiftUI with representables and hosting controllers.

## When to use this skill
- The user asks for work involving: uikit, appkit, representable, interop.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Wrap UIKit/AppKit views with UIViewRepresentable/NSViewRepresentable.
2. Use a Coordinator for delegates and target-action.
3. Update the wrapped view in updateUIView only when values change.
4. Embed SwiftUI in UIKit with UIHostingController and sizingOptions.
5. Manage lifecycle and memory (weak delegates).

## Rules
- Keep the bridge thin.
- SwiftUI state stays the source of truth.

## Verification
- [ ] Two-way updates verified.
- [ ] No leaks after dismiss.

## Avoid
- Recreating views on every update.
- Strong delegate cycles in coordinators.

## Recommended SwiftCode tools
- `swift_list_types`
- `scan_objc_attributes`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
