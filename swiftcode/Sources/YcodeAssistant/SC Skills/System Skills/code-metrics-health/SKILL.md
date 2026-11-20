---
name: code-metrics-health
description: "Assess codebase health with metrics: size, complexity, churn and test ratio."
category: Code Quality
tags: [metrics, complexity, health]
tools: [count_file_lines, file_long_functions_report, file_nesting_depth_report, git_contributor_summary]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Code Metrics Health

Assess codebase health with metrics: size, complexity, churn and test ratio.

## When to use this skill
- The user asks for work involving: metrics, complexity, health.
- You are about to change code in the Code Quality area and want SwiftCode's standard workflow.

## Workflow
1. Collect size and language stats.
2. Find long and deeply nested functions.
3. Combine with churn from git history.
4. Prioritize hotspots (high churn × complexity).

## Rules
- Metrics guide, not judge.
- Track trends.

## Verification
- [ ] Hotspot list produced.
- [ ] Top items have plans.

## Avoid
- Optimizing metrics for their own sake.
- Ignoring churn.

## Recommended SwiftCode tools
- `count_file_lines`
- `file_long_functions_report`
- `file_nesting_depth_report`
- `git_contributor_summary`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
