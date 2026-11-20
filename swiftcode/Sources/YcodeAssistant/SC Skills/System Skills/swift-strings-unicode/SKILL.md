---
name: swift-strings-unicode
description: "Handle Swift Strings, Characters, Unicode and performance correctly."
category: Swift Language
tags: [strings, unicode, text processing]
tools: [text_statistics, text_regex_test, file_encoding_report]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Swift Strings Unicode

Handle Swift Strings, Characters, Unicode and performance correctly.

## When to use this skill
- The user asks for work involving: strings, unicode, text processing.
- You are about to change code in the Swift Language area and want SwiftCode's standard workflow.

## Workflow
1. Iterate by Character for user-visible text, utf8 for bytes.
2. Use Regex/RegexBuilder or NSRegularExpression for patterns.
3. Normalize and compare with localized/case-insensitive APIs where user facing.
4. Avoid repeated index offsetting in loops.

## Rules
- Never assume one char = one byte.
- Use Substring for slices, convert when storing.

## Verification
- [ ] Emoji and combining-character tests pass.
- [ ] No O(n^2) index math.

## Avoid
- NSString length for UI counts.
- Byte-slicing UTF-8 text.

## Recommended SwiftCode tools
- `text_statistics`
- `text_regex_test`
- `file_encoding_report`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
