---
name: swiftui-navigation
description: "Implement NavigationStack/NavigationSplitView with value-based, testable routing."
category: UI Design
tags: [navigation, NavigationStack, routing, deep links]
tools: [scan_navigation_view_deprecated, swift_list_swiftui_views]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swiftui Navigation

Implement NavigationStack/NavigationSplitView with value-based, testable routing.

## When to use this skill
- The user asks for work involving: navigation, NavigationStack, routing, deep links.
- You are about to change code in the UI Design area and want SwiftCode's standard workflow.

## Workflow
1. Replace NavigationView usages found by scan_navigation_view_deprecated.
2. Model routes as a Hashable enum and keep a NavigationPath in a router object.
3. Use navigationDestination(for:) per route type.
4. Handle deep links by parsing URLs into routes.
5. Use NavigationSplitView for macOS/iPad sidebar layouts.

## Rules
- Navigation state must be serializable for restoration.
- No navigation side effects inside view bodies.

## Verification
- [ ] Deep link to each route works.
- [ ] Back navigation preserves state.

## Avoid
- NavigationLink(isActive:) patterns.
- Global singletons mutating navigation from anywhere.

## Recommended SwiftCode tools
- `scan_navigation_view_deprecated`
- `swift_list_swiftui_views`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
