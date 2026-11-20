# /debug — Debug

Diagnose a failure from real build, compiler, runtime and crash evidence.

`/debug` is a SwiftCode built-in action available from the Assist and Meta Assist slash palettes. It switches the agent into a focused task prompt (`### DEBUG ACTIVE`) scoped to the argument, or to the whole workspace when no argument is given. This file is the specification the agent reads to understand what the action means.

---

## 1. Syntax & Invocation

```text
/debug [issue]
```

- Without an argument the issue defaults to the workspace (or, for `/summarize`, the whole conversation).
- The prompt is sent immediately in Agent mode.

---

## 2. Workflow

1. Analyze the latest build log with `build_log_analyze`.
2. Analyze diagnostics with `compiler_diagnostics_engine` and runtime behavior with `runtime_diagnostics_engine`.
3. Parse crash logs with `crash_log_parse` when one exists.
4. Report the root cause with proof, then propose the fix.

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
