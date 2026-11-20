---
name: abtest
description: "Run A/B experiments with deterministic assignment, exposure logging, and a kill switch."
category: Product
tags: [ab-testing, experiments, feature-flags]
tools: [search_text, file_read, project_test]
version: 1.0.0
source: swiftcode-system
license: MIT
---

# A/B Testing

Run A/B experiments with deterministic assignment, exposure logging, and a kill switch.

## Purpose

This skill covers product experimentation in the **Product** area. Run A/B experiments with deterministic assignment, exposure logging, and a kill switch.

The outcome it produces is a concrete, verifiable result — not a plan or a suggestion. When this skill is applied well, the work ends with evidence: findings tied to specific files and lines, changes that can be reviewed in a diff, and checks that were actually run. The agent does not report success on the basis of having written code or having run a scan; it reports success on the basis of what the tools and tests showed afterward.

Use this skill as the operating procedure for any task whose core is A/B testing, experiments, assignment. It defines what to gather first, which tools to call, in what order, how to judge each intermediate result, and what must be true before the work is reported as complete. When the task touches more than one area, this skill still governs its own part; coordinate with the other relevant skills rather than folding their work into this one.

A well-run experiment gives a trustworthy answer: assignment is stable per user, exposure is logged exactly once, the control group is a real control, and a kill switch can end the experiment without shipping a new build.

## When to use

- The user asks for work involving: A/B testing, experiments, assignment.
- You are about to change code in the Product area and want SwiftCode's standard workflow.
- You are about to change code in the Product area and want SwiftCode's standard workflow for abtest.
- A review, audit, or investigation surfaces an issue in this area and you need a repeatable way to confirm it, fix it, and prove the fix.

## When NOT to use

- Do not use this skill as a substitute for a different skill that owns the task. If the real work is in another area (a different category or a different named skill), use that skill instead and let this one stay out of the way.
- Do not use this skill to justify work the user did not ask for. A skill describes how to do a task well; it does not authorize expanding the scope of the task.
- Do not use this skill when the inputs it requires are missing and cannot be obtained. Guessing at the inputs and proceeding anyway produces unverifiable work — stop and say what is missing instead.
- Do not use this skill for a one-off question that only needs an answer. If nothing will be changed, inspected, or verified, answer directly instead of running the full procedure.

## Inputs

Gather these before starting the procedure. Do not begin changing code until the inputs that define the current state are in hand — otherwise the agent cannot tell whether it improved anything.

- The user's request in their own words, including any constraints, deadlines, or definitions of done they stated.
- The hypothesis, the variants, the metric that decides the winner, and the minimum sample the experiment needs.
- The assignment mechanism and where the assignment is persisted, plus the existing code paths the variants will change.
- The files in scope: the source, configuration, and resource files the work will touch, with their current contents read, not assumed.
- The current state of the workspace: which files are involved, what the relevant code looks like today, and whether the working tree is clean or already carries uncommitted changes.
- Baseline evidence: the output of `search_text` on the current code, so the after-state can be compared against a real before-state rather than against memory.
- Any prior findings, reports, or decisions about this area, so the work builds on what is already known instead of re-discovering it.

If an input cannot be obtained — a file does not exist, a tool fails, the user's intent is unclear — record that explicitly and decide whether the procedure can still proceed safely. Missing a baseline is a reason to proceed carefully, not a reason to skip verification later.

## Step-by-step procedure

Follow the steps in order. Each step names the tool to call where one exists and states how to verify that step's output before moving on. Do not skip a verification and catch up later — a step whose output was never checked is a step that may not have happened.

### Step 1 — Restate the goal and gather the inputs

Restate the goal in one or two sentences and list the success criteria the user would recognize. Collect the inputs listed above. If the request is ambiguous between two readings, ask one targeted question naming the options instead of silently choosing the larger scope.
Verify this step by confirming the restated goal matches the user's words — if it does not, the rest of the procedure is aimed at the wrong target.

### Step 2 — Run the diagnostic tools and read the actual output

Run `search_text`, `file_read`, `project_test` against the files in scope. Read the full output — findings, file paths, line numbers, and any warnings — rather than skimming for a summary line. A tool that returns no findings is a result, not an absence of information: record 'zero findings from search_text' explicitly.
Verify this step by confirming the tool ran against the intended files (check the paths in its output) and that its output is complete, not truncated or erroring.

### Step 3 — Define variants and deterministic assignment

Give each variant a stable identifier and assign users deterministically from a stable user key so the same user always sees the same variant across launches.
Verify this step by checking its direct output: if it is a scan, confirm the findings list; if it is a code change, confirm the diff shows exactly the intended change and nothing else; if it is a test or build, confirm the exit status and read the failing lines rather than assuming success.

### Step 4 — Log exposure exactly once

Emit a single exposure event the first time a user actually sees the variant, and never again for that user, so the analysis counts exposed users rather than view appearances.
Verify this step by checking its direct output: if it is a scan, confirm the findings list; if it is a code change, confirm the diff shows exactly the intended change and nothing else; if it is a test or build, confirm the exit status and read the failing lines rather than assuming success.

### Step 5 — Guard the experiment with a kill switch

Put a remote flag in front of the experiment that forces every user to control when enabled, and verify the flag takes effect without a new build.
Verify this step by checking its direct output: if it is a scan, confirm the findings list; if it is a code change, confirm the diff shows exactly the intended change and nothing else; if it is a test or build, confirm the exit status and read the failing lines rather than assuming success.

### Step 6 — Analyse against the pre-registered metric

Compare the variants only on the metric registered before launch, and report the sample size and confidence alongside the result instead of picking the metric that looks best afterward.
Verify this step by checking its direct output: if it is a scan, confirm the findings list; if it is a code change, confirm the diff shows exactly the intended change and nothing else; if it is a test or build, confirm the exit status and read the failing lines rather than assuming success.

### Step 7 — Apply the change in the smallest safe increment

Make the smallest change that achieves the step's goal. Keep unrelated files untouched and keep the diff reviewable — one concern per change. For destructive or irreversible operations (deleting files, rewriting history, removing data, changing shared configuration), confirm with the user first unless the user already authorized that exact operation.
Verify this step by reviewing the diff (`git diff --stat` and the full diff of each touched file) and confirming it contains only the intended change.

### Step 8 — Re-run the checks and compare against the baseline

Re-run the same tools and tests that produced the baseline, on the same scope. Compare before and after: findings that should be gone must be gone, and no new findings, warnings, or failures may appear. If a check that passed before now fails, the change introduced a regression — stop and investigate before continuing.
Verify this step by recording the before/after comparison explicitly in the completion report.

### Step 9 — Report findings, changes, and open items

Write the completion report described in Verification below. State what was found (with file:line references), what was changed, what was verified, and what remains open. Do not report work as complete when a verification step was skipped — say which check was skipped and why.

## Edge cases and failure modes

These are the ways this kind of work most often goes wrong. For each one, the skill states how to detect it, how to recover, and when to stop and report instead of guessing.

- Assignment changes across launches — a random assignment per launch corrupts the experiment; persist the assignment or derive it deterministically.
- Exposure is logged without assignment — an exposure event with no variant attached cannot be attributed to any group.
- A variant leaks into persisted state — a user who saw variant B must not keep B's data after the experiment ends and the flag is removed.
- **The tool returns nothing.** Distinguish 'zero findings' from 'the tool failed or scanned the wrong scope'. Check the tool's output for errors, confirm the paths it scanned, and re-run with a known-bad input if you need to prove the tool is working.
- **Findings conflict.** Two tools or two readings disagree about the same code. Do not pick the more convenient one — read the code yourself, determine which reading is correct, and record the reasoning.
- **The scope is bigger than expected.** The scan or investigation reveals a problem far larger than the request. Do not silently expand the task: finish the requested scope, report the wider problem with evidence, and let the user decide whether to extend the work.
- **A fix breaks something else.** A change that fixes the target issue introduces a new failure elsewhere. Revert the change, keep the evidence of both states, and report the trade-off instead of shipping a fix that creates a new problem.
- **Intent is unclear.** The user's request can be read two ways and the difference changes the outcome. Ask one targeted question naming the two readings. Do not guess when the cost of guessing wrong is rework or data loss.

## Worked example

A realistic walkthrough of this skill applied to a concrete task in the app. The paths and commands are illustrative of the shape of the work; adapt the file paths to the actual workspace and verify every result against real tool output rather than assuming the example's outcome.

**Situation.** The user asks for work in the Product area: Run A/B experiments with deterministic assignment, exposure logging, and a kill switch. The current code has no experiment infrastructure, so there is no baseline and no prior findings to rely on.

**1. Gather inputs.** Identify the files in scope and run `search_text` to establish the baseline. Record the findings with their file:line references before changing anything.

**2. Follow the procedure.** Work through the steps above in order, starting with the diagnostic output. For each step, check its output before moving on — for example, after a scan step, confirm the findings list is complete and the scanned paths are the intended ones.

**3. Apply the change.** Make the smallest change that addresses the top-priority finding, keeping unrelated files untouched. Review the diff with `git diff --stat` followed by the full diff, and confirm it contains only the intended change.

**4. Verify.** Re-run `search_text` on the same scope. The expected outcome is that assignment is stable across launches, exposure is logged once per user, and the kill switch returns everyone to control. If a finding remains, it is either a different instance of the same issue (fix it the same way) or a false positive (record the reasoning and the evidence for that judgment — do not silently ignore it).

**5. Report.** Write the completion report with findings (file:line references), changes made, verification performed, and open items. Example of an honest report line: 'Ran search_text on the in-scope files; found and fixed the top-priority findings, re-ran and confirmed the expected after-state; 1 related issue in an adjacent file is recorded as an open item.' Never report 'all fixed' when the re-run has not been performed.

## Rules

- Assignment is stable per user for the whole experiment.
- Exactly one exposure event per user, logged only when the variant is actually seen.
- The kill switch defaults to control and is verified to work without a new build.
- Ground every claim in tool output, file contents, or test results you actually observed. Never assert a finding, a fix, or a verification from memory or from what the code 'probably' does.
- Stay inside the scope of the request. Do not expand into adjacent areas, do not refactor unrelated code, and do not rename modules, imports, or public API surfaces as a side effect of this work.
- Confirm before any destructive operation: deleting files or data, rewriting history, removing configuration, or changing shared state. If the user already authorized that exact operation, proceed and say so; otherwise ask.
- Never invent a tool, a capability, or a result. If a needed tool does not exist, say so and do the work another verifiable way — do not fabricate tool output.
- Never store secrets in UserDefaults, plist files, logs, or source code, and never print a secret, token, or credential value in output, logs, or reports. This applies to every skill, not only security skills.

## Verification

Run every check below before reporting success. A check that was not run is reported as not run — never as passed.

- [ ] The same user receives the same variant across launches.
- [ ] Each user logs exactly one exposure event.
- [ ] Enabling the kill switch returns every user to control.
- [ ] The diagnostic tools were re-run after the change on the same scope, and the before/after comparison is recorded.
- [ ] The diff was reviewed in full and contains only the intended change.

### Completion report

The report the agent files when this skill's work is done must contain these fields:

- **Findings** — each finding with a file:line reference and severity, including findings that were investigated and judged not to be issues (with reasoning).
- **Changes made** — the files changed and what changed in each, with the diff available for review.
- **Verification performed** — the exact checks run (tools, tests, builds), their outcomes, and the before/after comparison.
- **Open items** — anything deferred, blocked, or needing the user's decision, with the reason it is open and what would resolve it.

## Recommended SwiftCode tools

- `search_text`
- `file_read`
- `project_test`

## Talking to the user

- State the plan in one or two sentences before making changes, then report what changed and how it was verified.
- Ask only when a real decision is needed; otherwise proceed with the safest reasonable default and say which default you chose.
