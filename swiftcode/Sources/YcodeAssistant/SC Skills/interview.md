# /interview — Interactive Requirement & Decision Interview Specification

The `/interview` slash command mandates an interactive interview phase prior to any code implementation or file mutation. Instead of making assumptions about ambiguous requirements, the agent pauses to formulate structured questions, present architectural alternatives, and gather user preferences using the native `plan-AskUser` decision tool.

---

## 1. Syntax & Invocation

```text
/interview <project-concept-or-feature-request>
```

### Examples
- `/interview Design a new collaborative canvas system for SwiftCode`
- `/interview We need to integrate background audio playback with lock screen controls`
- `/interview Refactor the project configuration inspector`

---

## 2. Operational Rules

1. **Pre-Implementation Requirement**: No file edits, deletions, or irreversible terminal commands may be executed until the interview questions are addressed.
2. **Plan Mode Enforcement**: Automatically sets `ExecutionMode.plan`.
3. **Structured Question Format**: Uses `plan-AskUser` to present concrete options with:
   - A clear problem statement or architectural dilemma.
   - Recommended choices marked with `(Recommended)`.
   - Multi-select capability when multiple features may be enabled concurrently.
   - Support for custom text answers from the user.
4. **Focused Inquiries**: Questions must focus on technical trade-offs (e.g. SQLite vs SwiftData, polling vs websockets, SwiftUI vs AppKit), UX expectations, and compatibility requirements. Avoid trivial yes/no queries.

---

## 3. Tool Calling Patterns & Internal Architecture

When `/interview` is received:
1. `SlashCommandExecutionEngine.shared` switches the session execution mode:
   ```swift
   UserDefaults.standard.set(ExecutionMode.plan.rawValue, forKey: "com.swiftcode.assist.executionMode")
   ```
2. Injects system instructions:
   ```text
   ### INTERVIEW PHASE ACTIVE
   Do not modify code yet. Interview the user on architectural decisions, design tradeoffs, and technical requirements. Formulate structured questions using the `plan-AskUser` tool with recommended options before preparing the final execution plan.
   ```
3. When the user selects or inputs answers via the interactive decision prompt, the responses are recorded into session memory and the execution plan is updated.

---

## 4. Behavior Specifications

1. **Decision Sheet**: Displays an interactive question card directly inside the Assist timeline or modal sheet.
2. **Clarification Summary**: Synthesizes the user's answers into a formal requirement brief.
3. **Transition to Execution**: Once all requirements are aligned, presents a "Proceed with Implementation" action to unlock Autopilot mode.
