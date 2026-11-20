---
name: build-failure-diagnosis
description: "Diagnose and fix compiler and linker errors systematically."
category: Build & Tooling
tags: [build errors, compiler, linker]
tools: [swiftpm_build_target, swift_typecheck_file, binary_linked_libraries]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Build Failure Diagnosis

Diagnose and fix compiler and linker errors systematically.

## When to use this skill
- The user asks for work involving: build errors, compiler, linker.
- You are about to change code in the Build & Tooling area and want SwiftCode's standard workflow.

## Workflow
1. Rebuild and capture the first error, not the last.
2. Classify: syntax, type-check, missing symbol, linker, signing.
3. Read the referenced code and its dependencies.
4. Apply the minimal fix and rebuild the target.
5. Run tests touched by the change.

## Rules
- Fix root errors first; later ones are often cascades.
- Never silence errors with unsafe flags.

## Verification
- [ ] Clean build passes.
- [ ] No new warnings.

## Avoid
- Random clean/rebuild cycles without reading errors.
- Commenting out code to compile.

## Recommended SwiftCode tools
- `swiftpm_build_target`
- `swift_typecheck_file`
- `binary_linked_libraries`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
