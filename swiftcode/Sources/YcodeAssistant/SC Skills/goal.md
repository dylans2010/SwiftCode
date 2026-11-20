# /goal — Autonomous Goal Mode Specification

The `/goal` slash command transitions the Assistant into fully autonomous Goal Mode. In this state, the agent operates in an end-to-end execution loop without pausing for routine confirmation, working tirelessly until the requested objective is completely achieved, tested, and verified against the codebase.

---

## 1. Syntax & Invocation

```text
/goal <objective-or-target>
```

### Examples
- `/goal Migrate all legacy CoreData models to SwiftData and verify builds`
- `/goal Fix all strict concurrency warnings in YcodeAssistant and run test suite`
- `/goal Implement dark mode support across all inspector panels`

---

## 2. Operational Rules

1. **Uninterrupted Execution**: The agent must not pause or ask rhetorical questions ("Should I proceed?", "Would you like me to do X?"). It formulates execution steps internally, selects tools, modifies files, and executes verification autonomously.
2. **Autopilot Discipline**: Sets `ExecutionMode.autopilot` on the active session.
3. **Goal Expansion**: Engages `AssistGoalExpansionEngine` to continuously decompose root objectives into sub-goals and monitor milestone progress.
4. **Autonomous Error Recovery**: If compilation errors or test failures occur, the agent must diagnose the root cause, inspect files, apply corrective edits, and rebuild until exit code 0 is attained.
5. **Quality Gate**: Execution only concludes when all changes are verified and confirmed working, or a fatal unrecoverable external dependency is reached.

---

## 3. Tool Calling Patterns & Internal Architecture

When `/goal` is invoked:
1. `SlashCommandExecutionEngine.shared` sets `sessionState.executionMode = .autopilot` and `sessionState.isAutonomousExpansion = true`.
2. The user objective is recorded as `sessionState.rootGoal`.
3. Injects a system instruction:
   ```text
   ### AUTONOMOUS GOAL MODE ACTIVE
   Pursue the user's objective end-to-end without pausing. Ground your understanding with codebase search, make code modifications, compile, verify, and resolve issues autonomously until complete.
   ```
4. If an objective was provided in the command, immediately launches `AssistManager.shared.sendMessage(...)` with autopilot envelope flags.

---

## 4. Behavior Specifications

- **UI Indicators**: Displays an active "Autonomous Goal Mode" indicator in the composer toolbar and main view header.
- **Activity Stream**: Surfaces structured goal progress cards in the Assistant timeline as each sub-goal transitions from pending to completed.
- **Completion Signal**: Emits a final accomplishment summary detailing all files touched, tests passed, and verification artifacts produced.
