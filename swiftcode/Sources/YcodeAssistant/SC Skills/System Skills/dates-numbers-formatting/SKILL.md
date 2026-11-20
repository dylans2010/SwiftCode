---
name: dates-numbers-formatting
description: "Format dates, numbers, currency and measurements correctly for every locale."
category: Internationalization
tags: [formatting, dates, currency, locale]
tools: [scan_formatter_allocations, date_format_convert, unix_timestamp_convert]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# Dates Numbers Formatting

Format dates, numbers, currency and measurements correctly for every locale.

## When to use this skill
- The user asks for work involving: formatting, dates, currency, locale.
- You are about to change code in the Internationalization area and want SwiftCode's standard workflow.

## Workflow
1. Use FormatStyle APIs (.formatted()).
2. Store dates in UTC; display in user's time zone.
3. Use Decimal for money.
4. Use Measurement with unit conversion.
5. Parse server dates with ISO8601 strategies.

## Rules
- en_US_POSIX for fixed-format parsing.
- Never format currency manually.

## Verification
- [ ] Tests in several locales pass.
- [ ] Time zone edge cases tested.

## Avoid
- Double for money.
- Creating formatters in loops.

## Recommended SwiftCode tools
- `scan_formatter_allocations`
- `date_format_convert`
- `unix_timestamp_convert`

## Talking to the user
- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
