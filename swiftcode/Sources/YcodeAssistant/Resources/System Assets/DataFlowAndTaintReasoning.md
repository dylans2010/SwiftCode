# Data-Flow and Taint Reasoning

<!-- system-index-depends: ControlFlowRecovery.md -->

Data-flow reasoning follows a value from where it is created to where it
is used. Taint reasoning is the special case where the value comes from an
untrusted source. Assist uses both to answer "where did this value come
from" and "where does it go".

## When to retrieve

- The user asks where a value originates or what influences it.
- A bug involves a bad value, and the source of the value is unknown.
- A security question turns on whether untrusted input reaches a
  sensitive operation.

## Core concepts

- Definitions and uses: every value is defined somewhere and used
  somewhere. The chain between them is the data flow.
- Propagation: a value flows through assignments, arguments, returns, and
  memory. Each step preserves the flow; a step that transforms the value
  (encoding, hashing, formatting) changes what can be said about it.
- Sources: where values enter the function (arguments, globals, memory
  reads, calls). A source outside the function bounds what the function
  alone can prove.
- Sinks: where values are consumed (stores, calls, branches, returns). A
  value that never reaches a sink is dead for this question.
- Taint: a label for data from an untrusted source. Taint propagates
  through operations until a sanitizer removes it. Sanitization must be
  verified, not assumed.

## How to report data flow

- Trace the chain step by step: source, each transformation, and the sink.
- Name the step where confidence drops: an indirect call, a memory write
  through an unknown pointer, or a value that escapes the function.
- For taint questions, state the source, the path, and whether any step
  sanitizes. If no sanitizer is found, say so; do not assume one exists.
- Separate "this value can reach the sink" from "this value does reach
  the sink on the path the user cares about". Possibility and actuality
  are different claims.

## Common mistakes

- Following one path and reporting it as the only path. Branches multiply
  flows.
- Assuming a transformed value keeps the original's properties. Encoding
  and hashing break taint and break equality alike.
- Treating a global as a constant. Globals change, and a stale reading
  misleads.
- Confusing a value's type with its provenance. A string can be trusted
  or tainted regardless of its type.

## Cross-references

- Control flow: `ControlFlowRecovery.md`
- String analysis: `StringAndConstantAnalysis.md`
- Type reconstruction: `TypeReconstruction.md`

## Limits

- Static data-flow reasoning is bounded by what the function shows.
  Values that arrive from outside, or escape through memory, cap the
  analysis. Report the cap.
- Taint analysis answers reachability, not exploitability. A tainted sink
  is a finding that needs a severity judgment, not a verdict by itself.
