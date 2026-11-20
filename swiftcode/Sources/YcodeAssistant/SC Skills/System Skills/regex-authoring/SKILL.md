---
name: regex-authoring
description: "Write correct, readable and safe regular expressions."
category: Code Quality
tags: [regex, patterns, text]
tools: [text_regex_test, text_regex_test, text_regex_replace]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Regex Authoring

Write correct, readable and safe regular expressions.

## When to use this skill
- The user asks for work involving: regex, patterns, text.
- You are about to change code in the Code Quality area and want SwiftCode's standard workflow.

## Workflow
1. Write examples that must and must not match.
2. Build the pattern incrementally with text_regex_test.
3. Anchor and use non-greedy quantifiers.
4. Prefer RegexBuilder for complex Swift patterns.

## Rules
- Avoid catastrophic backtracking.
- Comment complex patterns.

## Verification
- [ ] All examples behave as expected.
- [ ] Performance acceptable on large input.

## Avoid
- Parsing HTML with regex.
- Unanchored greedy .*.

## Recommended SwiftCode tools
- `text_regex_test`
- `text_regex_test`
- `text_regex_replace`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
