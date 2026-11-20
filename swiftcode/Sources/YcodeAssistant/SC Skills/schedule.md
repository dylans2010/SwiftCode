# /schedule — Task & Cron Scheduling Specification

The `/schedule` slash command allows users and autonomous agents to defer, time, or periodically execute tasks within SwiftCode. It bridges interactive assistant sessions with background execution loops, cron daemons, and delayed reminder alerts.

---

## 1. Syntax & Invocation

```text
/schedule <duration | cron-expression> [options] <instruction-or-prompt>
```

### Examples
- `/schedule in 15m "Run test suite and verify coverage"`
- `/schedule 3600 "Check git remote for newly pushed PRs"`
- `/schedule cron "0 9 * * 1-5" "Summarize pending issues and run daily build audit"`
- `/schedule --condition any 600 "Monitor subagent build and report completion"`

### Arguments
- **Duration / Cadence**:
  - `DurationSeconds`: Integer seconds (e.g. `60`, `300`, `3600`).
  - Human duration string: `in 5m`, `in 2h`, `after 30s`.
  - `CronExpression`: Standard 5-field cron string (e.g., `*/10 * * * *`, `0 0 * * *`).
- **Prompt / Action**: Natural language instruction describing the task to execute when fired.
- **Flags**:
  - `--exact`: Cron only. Set exact wall-clock timing without jitter.
  - `--daemon`: Keeps recurring cron active across session completions.
  - `--condition <never|any|senderId>`: Cancels the timer early if a matching notification arrives.

---

## 2. Operational Rules

1. **Non-Blocking Execution**: Never execute shell `sleep` commands in the terminal or block the main thread. Scheduling must register a timer or cron with `AssistScheduledTaskManager`.
2. **Persistence**: Scheduled jobs are tracked in the active project session. If the application restarts, persistent daemons resume from disk.
3. **Reactive Notification**: When a schedule triggers:
   - A high-priority system notification or wake-up message is injected into the active conversation.
   - The Assistant is invoked with the scheduled prompt as the root objective.
4. **Cancellation**: Users can cancel or list active schedules at any time using `/schedule list` or `/schedule cancel <id>`.

---

## 3. Tool Calling Patterns & Internal Architecture

When the agent receives `/schedule`:
- It maps the parameters to `AssistScheduledTaskManager.shared.scheduleTask(...)`.
- If duration is specified, a one-shot `TaskTimer` is initialized using `Task.sleep` or `DispatchSourceTimer`.
- If a cron expression is provided, the cron parser calculates the next occurrence timestamp and sets up an interval runner.
- The task registers with `WorkerScheduler` or `AssistManager` to deliver the trigger prompt directly into the agentic loop.

---

## 4. Behavior Specifications

1. **Validation**: Validate that either a valid duration (> 0 seconds) or a valid 5-part cron syntax is provided.
2. **Confirmation**: Emit a rich status card displaying the scheduled execution time, recurrence pattern, and payload summary.
3. **Execution**: On trigger, if the conversation is idle, automatically initiate the run. If busy, queue the trigger message behind current activity.
