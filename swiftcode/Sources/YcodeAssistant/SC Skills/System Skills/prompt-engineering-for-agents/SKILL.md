---
name: prompt-engineering-for-agents
description: "Write effective prompts and system instructions for LLM-powered features."
category: AI & Agents
tags: [prompts, llm, agents]
tools: [system_asset_search, text_statistics]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Prompt Engineering For Agents

Write effective prompts and system instructions for LLM-powered features.

## When to use this skill
- The user asks for work involving: prompts, llm, agents.
- You are about to change code in the AI & Agents area and want SwiftCode's standard workflow.

## Workflow
1. Define role, goal, constraints and output format.
2. Provide examples of good outputs.
3. Separate instructions from untrusted data.
4. Evaluate with a fixed test set.

## Rules
- Be explicit about format.
- Guard against prompt injection.

## Verification
- [ ] Eval set pass rate tracked.
- [ ] Outputs parse reliably.

## Avoid
- Vague instructions.
- Mixing user data into instructions.

## Recommended SwiftCode tools
- `system_asset_search`
- `text_statistics`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
