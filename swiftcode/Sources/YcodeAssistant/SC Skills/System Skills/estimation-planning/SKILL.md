---
name: estimation-planning
description: "Estimate engineering work with ranges and explicit risks."
category: Product
tags: [estimation, planning, risk]
tools: [workspace_extension_stats, git_contributor_summary]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Estimation Planning

Estimate engineering work with ranges and explicit risks.

## When to use this skill
- The user asks for work involving: estimation, planning, risk.
- You are about to change code in the Product area and want SwiftCode's standard workflow.

## Workflow
1. Break work into tasks under a day.
2. Estimate ranges (best/likely/worst).
3. Identify unknowns and spikes.
4. Re-estimate as you learn.

## Rules
- Communicate uncertainty.
- Include testing and review time.

## Verification
- [ ] Plan reviewed.
- [ ] Variance tracked.

## Avoid
- Single-point estimates.
- Ignoring integration time.

## Recommended SwiftCode tools
- `workspace_extension_stats`
- `git_contributor_summary`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
