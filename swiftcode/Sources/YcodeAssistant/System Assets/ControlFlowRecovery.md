# Control-Flow Recovery

<!-- system-index-depends: ARM64ReadingForAssist.md, X86_64ReadingForAssist.md -->

Control-flow recovery reconstructs the shape of a function: its blocks,
branches, loops, and exits. It turns a flat instruction stream into a
structure Assist can reason about and explain.

## When to retrieve

- The user asks how a function is structured or where a branch leads.
- A DecompileAssist result needs a control-flow check.
- A crash or a bug report points at a specific path through a function.

## What recovery establishes

- Basic blocks: straight-line runs of instructions ending in a branch,
  call, or return. Blocks are the unit of control flow.
- Edges: which blocks can follow which. An edge is a claim about possible
  flow, not about taken flow.
- Branches: conditional paths and their conditions, stated as what is
  tested, not as a recital of flags.
- Loops: back edges that repeat a block, with their entry, exit, and
  termination condition where recoverable.
- Switches: multi-way branches, often through a table. The table's size
  and entries bound the possible targets.
- Exits: returns and exits, including early returns that split a function
  into distinct paths.

## How to report control flow

- Describe the shape first: linear, branching, looping, or switch-driven.
- Name the decision at each branch in plain language: what value is
  tested and what each outcome means.
- Separate reachable paths from dead code. A block with no incoming edge
  may be dead, data, or a recovery error; say which is most likely.
- Flag indirect control flow explicitly. A computed target is an unknown,
  not a gap to fill with a guess.

## Common mistakes

- Treating a fall-through as a branch. Falling through is the default
  path, and it matters for reading order.
- Assuming every loop in the graph is a loop in the source. Compilers
  create loops for copies, table walks, and cleanup.
- Merging two paths that only share a block. Shared blocks are not shared
  intent.
- Trusting a recovered graph built from a wrong function boundary. See
  `FunctionBoundaryRecovery.md`.

## Cross-references

- Core concepts: `swiftcode/Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/DECOMPILATION.md`
- Function boundaries: `FunctionBoundaryRecovery.md`
- Data flow: `DataFlowAndTaintReasoning.md`

## Limits

- Recovered control flow is a hypothesis about the source structure. The
  instructions are the ground truth; the graph is an interpretation.
- Indirect branches cap what recovery can state. Report the cap.
