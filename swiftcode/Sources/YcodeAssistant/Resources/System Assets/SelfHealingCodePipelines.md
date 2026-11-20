<!-- system-index-depends: BuildAndTesting.md, AgentMode.md -->
# Self-Healing Code Pipelines & Diagnostic Repair Loops

Autonomous error recovery protocols for compiling, diagnosing errors, localizing fault lines, and repairing code without human intervention.

---

## 1. The Autonomous Repair Loop
```
[Code Mutation Applied]
         |
         v
  [Trigger Build]
         |
   Build Succeeded?
     /        \
   YES         NO
   /             \
[Pass]     [Parse Compiler Diagnostics]
                 |
           [Localize Error AST]
                 |
           [Apply Correction Patch]
                 |
           (Repeat Loop, Max 3 attempts)
```

---

## 2. Diagnostic Localization Rules
1. Parse the primary error location (`path:line:col`) from compiler logs.
2. Inspect the enclosing method and surrounding lines using `file_read` with a targeted line range.
3. Determine root cause:
   - Missing import -> Add import at top of file.
   - Type mismatch -> Adjust return type or call site.
   - Concurrency isolation error -> Add `@MainActor` or convert to value type.
4. Apply the targeted fix using `code_replace` and re-run `project_build`.
