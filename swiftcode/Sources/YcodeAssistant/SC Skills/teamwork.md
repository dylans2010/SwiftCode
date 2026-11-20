# /teamwork — Multi-Agent Subagent Coordination Specification

The `/teamwork` slash command mandates that the Assistant orchestrate tasks using the native Workers system (`use_workers`). Rather than processing large, multifaceted codebases sequentially in a single turn, the coordinator decomposes the workload and assigns discrete, non-overlapping modules to parallel or sequenced subagents.

---

## 1. Syntax & Invocation

```text
/teamwork <complex-task-description>
```

### Examples
- `/teamwork Refactor UI components, models, and test targets in parallel`
- `/teamwork Audit all networking endpoints and generate integration tests for each service`
- `/teamwork Deconstruct legacy Objective-C bridge into separate Swift frameworks`

---

## 2. Operational Rules

1. **Mandatory Subagent Delegation**: Tasks exceeding 3 files or spanning multiple distinct subsystems MUST be decomposed into workers.
2. **Scope Isolation**: Every worker assignment must define an explicit `scope` (directory or module) and disjoint `targetFiles` to eliminate write collisions.
3. **Task Brevity**: Each subagent's task description must be concise, concrete, and self-contained (under 500 characters).
4. **Coordination & Synthesis**: The main coordinator manages the swarm: tracks worker statuses, aggregates changes, resolves inter-agent dependencies, and conducts final integration testing.
5. **Tool Restriction**: Workers communicate with the coordinator via `worker_message` and execute tools in their isolated environment.

---

## 3. Tool Calling Patterns & Internal Architecture

When `/teamwork` is triggered:
1. `SlashCommandExecutionEngine.shared` configures the session policy to enforce worker delegation.
2. Injects system instructions:
   ```text
   ### TEAMWORK & WORKER DELEGATION MANDATED
   You MUST decompose this task into subtasks and invoke workers via `use_workers`.
   Assign distinct names, non-overlapping scopes, and concise responsibilities to each worker.
   ```
3. Connects with `WorkerScheduler.shared` and `WorkerEngine.shared` to track active worker instances.
4. Updates the Assistant UI to display the Workers panel and subagent status badges.

---

## 4. Behavior Specifications

1. **Decomposition Card**: Surfaces a task breakdown showing planned workers, their assigned scopes, and dependency graph.
2. **Parallel Progress**: Renders real-time status pills for each active worker (`running`, `verifying`, `completed`).
3. **Recap Generation**: Uses `WorkerRecapGenerator` to assemble a cohesive post-task summary for the user once all workers land their changes.
