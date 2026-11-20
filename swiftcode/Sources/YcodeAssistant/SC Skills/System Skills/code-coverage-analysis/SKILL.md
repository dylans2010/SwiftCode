---
name: code-coverage-analysis
description: "Measure code coverage and target untested critical paths."
category: Testing
tags: [coverage, testing, quality]
tools: [test_run_single, swift_list_test_functions]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Code Coverage Analysis

Measure code coverage and target untested critical paths.

## When to use this skill
- The user asks for work involving: coverage, testing, quality.
- You are about to change code in the Testing area and want SwiftCode's standard workflow.

## Workflow
1. Run swift test --enable-code-coverage or xcodebuild -enableCodeCoverage YES.
2. Export coverage with llvm-cov report.
3. Rank uncovered files by risk.
4. Add tests for critical uncovered branches.
5. Track coverage trend, not an absolute target.

## Rules
- Coverage is a signal, not a goal.
- Prioritize business logic.

## Verification
- [ ] Critical paths covered.
- [ ] Report attached to change.

## Avoid
- Testing getters for numbers.
- Excluding hard code to inflate %.

## Recommended SwiftCode tools
- `test_run_single`
- `swift_list_test_functions`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
