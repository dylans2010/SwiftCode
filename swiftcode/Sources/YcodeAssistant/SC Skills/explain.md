# /explain — Explain

Explain what code does, how it works and what depends on it.

`/explain` is a SwiftCode built-in action available from the Assist and Meta Assist slash palettes. It switches the agent into a focused task prompt (`### EXPLAIN ACTIVE`) scoped to the argument, or to the whole workspace when no argument is given. This file is the specification the agent reads to understand what the action means.

---

## 1. Syntax & Invocation

```text
/explain [target]
```

- Without an argument the target defaults to the workspace (or, for `/summarize`, the whole conversation).
- The prompt is sent immediately in Agent mode.

---

## 2. Workflow

1. Explain the target with `intel_explain_code`.
2. Cover what it does, how it works and why it is shaped that way.
3. List what depends on it.
4. Ground every claim in the actual code.

---

## 3. Operational Rules

1. Use the named native tools; if a tool is unavailable, use `tool_catalog_search` to find the closest registered equivalent and say so.
2. Ground every statement in tool output or code; never fabricate results.
3. Stay within the requested scope; confirm destructive operations.
4. Verify changes with a build and tests before reporting success.

---

## 4. Completion Report

- Findings or results with file and line references.
- Changes made (if any) and how they were verified.
- Open items and recommended next steps.
