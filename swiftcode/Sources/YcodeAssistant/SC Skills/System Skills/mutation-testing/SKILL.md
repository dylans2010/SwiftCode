---
name: mutation-testing
description: "Assess test-suite strength by introducing small code mutations."
category: Testing
tags: [mutation testing, test quality]
tools: [swiftpm_run_filtered_tests, file_regex_replace]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Mutation Testing

Assess test-suite strength by introducing small code mutations.

## When to use this skill
- The user asks for work involving: mutation testing, test quality.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Pick critical code with good coverage.
2. Introduce one mutation at a time (flip condition, change constant, remove call) on a scratch copy or branch.
3. Run the relevant tests; a surviving mutant means a missing assertion.
4. Add tests that kill survivors.
5. Revert all mutations.

## Rules
- Never commit mutations.
- Focus on business logic.

## Verification
- [ ] Survivors documented and addressed.
- [ ] Working tree clean afterwards.

## Avoid
- Mutating generated code.
- Leaving mutations in place.

## Recommended SwiftCode tools
- `swiftpm_run_filtered_tests`
- `file_regex_replace`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
