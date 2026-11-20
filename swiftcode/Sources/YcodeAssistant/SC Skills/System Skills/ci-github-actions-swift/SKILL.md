---
name: ci-github-actions-swift
description: "Set up GitHub Actions CI for Swift packages and Xcode projects."
category: Build & Tooling
tags: [ci, github actions, automation]
tools: [tool_catalog_search, swift_toolchain_info, xcodebuild_version_info]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Ci Github Actions Swift

Set up GitHub Actions CI for Swift packages and Xcode projects.

## When to use this skill
- The user asks for work involving: ci, github actions, automation.
- You are about to change code in the Build & Tooling area and want SwiftCode's standard workflow.

## Workflow
1. Read existing workflows.
2. Add jobs for build, test and lint on macOS (and Linux for packages).
3. Cache .build / DerivedData keyed on Package.resolved.
4. Select Xcode version explicitly.
5. Upload test results and fail fast.

## Rules
- CI mirrors local commands.
- Pin action versions.

## Verification
- [ ] Workflow green on a PR.
- [ ] Cache hits on second run.

## Avoid
- Secrets echoed in logs.
- Unpinned latest toolchains.

## Recommended SwiftCode tools
- `tool_catalog_search`
- `swift_toolchain_info`
- `xcodebuild_version_info`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
