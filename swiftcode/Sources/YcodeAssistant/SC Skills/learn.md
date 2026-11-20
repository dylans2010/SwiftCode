# /learn — Knowledge & Reusable Skill Capture Specification

The `/learn` slash command instructs the Assistant to reflect on recent interactions, user corrections, bug resolutions, or established workflows to distill reusable rules, persistent memory, or executable skill packages. This guarantees that valuable insights gained during a session persist across future conversations and workspace tasks.

---

## 1. Syntax & Invocation

```text
/learn [rule-or-skill-focus]
```

### Examples
- `/learn Remember that we strictly use Swift 6 Sendable and avoid DispatchQueue`
- `/learn Capture the build and packaging steps we just ran into an executable skill`
- `/learn Extract our styling tokens and design rules from this refactor`

---

## 2. Operational Rules

1. **Reflection & Extraction**: Analyzes recent turns in `AssistManager.shared.messages` or user-specified guidelines.
2. **Persistent Storage**:
   - High-level rules, coding conventions, and architectural preferences are persisted to `UserMemoryManager.shared` (`UserMemory.md`) under the `"Rules"` or `"Conventions"` category.
   - Comprehensive multi-step workflows are synthesized into modern skill packages located in `SkillIndex.shared.authoritativeSkillsDirectory/<SkillName>/SKILL.md`.
3. **No Redundancy**: Merges duplicate rules or updates existing entries without inflating memory size.
4. **Immediate Availability**: Newly captured rules and skills are immediately indexed and available for autocomplete in the slash (`/`) and mention (`@`) palettes.

---

## 3. Tool Calling Patterns & Internal Architecture

When `/learn` is executed:
1. `SlashCommandExecutionEngine.shared` examines the input argument and recent conversation history.
2. If the user provided a direct rule:
   - Invokes `UserMemoryManager.shared.saveEntry(key: value: category: "Rules")`.
3. If an executable skill is identified:
   - Formulates frontmatter (`name`, `description`) and detailed markdown instructions.
   - Writes the new skill definition to `SkillIndex.shared.authoritativeSkillsDirectory`.
   - Triggers `SkillIndex.shared.rebuildIndex()`.
4. Emits a confirmation card in the chat showing the captured rule key, value, and target location.

---

## 4. Behavior Specifications

1. **Memory Feedback**: Displays a card summarizing what was learned:
   - "Learned Rule: `StrictConcurrencyPolicy` saved to User Memory."
   - "Created Skill: `PackageReleaseWorkflow` indexed and ready for use via `/PackageReleaseWorkflow`."
2. **Instant Recall**: Future prompts automatically benefit from this context via `AssistContextBuilder`.
