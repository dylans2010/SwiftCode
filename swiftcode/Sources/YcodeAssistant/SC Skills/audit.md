# /audit — Security Audit

Audit code, access levels and permissions for security issues.

`/audit` is a SwiftCode built-in action available from the Assist and Meta Assist slash palettes. It switches the agent into a focused task prompt (`### SECURITY AUDIT ACTIVE`) scoped to the argument, or to the whole workspace when no argument is given. This file is the specification the agent reads to understand what the action means.

---

## 1. Syntax & Invocation

```text
/audit [scope]
```

- Without an argument the scope defaults to the workspace (or, for `/summarize`, the whole conversation).
- The prompt is sent immediately in Agent mode.

---

## 2. Workflow

1. Run `security_audit_scanner`, `access_level_audit` and `permissions_audit` on the scope.
2. Run `autonomous_review_engine` over the same scope.
3. Report every finding with file, line, severity and fix.
4. Prioritize exploitable issues first.

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
