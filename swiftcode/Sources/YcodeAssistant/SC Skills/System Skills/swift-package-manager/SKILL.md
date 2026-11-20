---
name: swift-package-manager
description: "Structure, maintain and debug Swift packages and their dependencies."
category: Build & Tooling
tags: [swiftpm, packages, dependencies]
tools: [swiftpm_describe_package, swiftpm_dependency_tree, swiftpm_dump_manifest, swiftpm_resolve_dependencies]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Package Manager

Structure, maintain and debug Swift packages and their dependencies.

## When to use this skill
- The user asks for work involving: swiftpm, packages, dependencies.
- You are about to change code in the Build & Tooling area and want SwiftCode's standard workflow.

## Workflow
1. Inspect the package with swiftpm_describe_package.
2. Organize targets by layer; keep tests per target.
3. Pin dependencies with version ranges; commit Package.resolved for apps.
4. Declare resources with .process/.copy.
5. Resolve and build to verify changes.

## Rules
- Minimal public API per module.
- Avoid unsafeFlags in libraries.

## Verification
- [ ] swift build and swift test pass.
- [ ] Dependency tree has no duplicates.

## Avoid
- Branch dependencies in releases.
- Circular target dependencies.

## Recommended SwiftCode tools
- `swiftpm_describe_package`
- `swiftpm_dependency_tree`
- `swiftpm_dump_manifest`
- `swiftpm_resolve_dependencies`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
