# Performance Budgets

<!-- system-index-depends: PerformanceProfilingInstruments.md -->

A performance budget is a number with a test behind it: launch under X,
a frame under Y, a search under Z. Without the number, "fast" is a feeling
and every regression is arguable. With it, a regression is a failing test.

## Budgets worth setting

- Cold launch to interactive: the time from double-click to a usable
  window. Measure on the slowest supported machine, not the developer's.
- First frame and scroll frame time: 16.7ms per frame at 60Hz, 8.3ms at
  120Hz ProMotion. A frame that misses its budget is a visible hitch.
- Interaction latency: tap-to-response for the five most common actions.
  Anything over ~100ms feels laggy; over 300ms feels broken.
- Memory ceiling: resident memory under sustained use, and growth over an
  hour of normal use. Growth without bound is a leak, not a cache.
- Energy: CPU wakeups per second at idle. An idle app should be near
  silent; a busy loop at idle drains a laptop battery.
- Binary and install size: the app download size, and the launch cost of
  loading it. See `BinarySizeOptimization.md` for the size side.

## Measuring honestly

- Measure release builds, not debug builds. Debug builds disable
  optimizations and enable checks that distort every number.
- Warm the caches once, then measure the steady state. A first-run
  measurement includes one-time costs that never recur.
- Measure on real hardware across the supported range, including the
  oldest machine the app claims to support.
- Record the machine, OS version, build, and workload with every number.
  A number without its conditions cannot be compared to the next run.
- Use Instruments (Time Profiler, Allocations, Leaks, Energy Log) for
  diagnosis and a scripted harness for the numbers. See
  `PerformanceProfilingInstruments.md`.

## Enforcing the budget

- Put the budget in a test or a CI check: launch time, a benchmark for
  the hot path, a memory ceiling on a scripted session.
- When a change exceeds a budget, the change is incomplete until the
  budget is met or the budget is consciously revised with a reason.
- Never revise a budget silently to make a red number green. A revised
  budget needs a recorded reason and a new number.
- Profile before optimizing. The hot path is rarely the code that looks
  slow; guessing wastes the optimization effort on the wrong function.

## Common budget breakers

- Synchronous work on the main thread: file I/O, JSON parsing, image
  decoding, regex on large text. Move it off the main actor.
- Layout thrash: views that invalidate layout in a loop, or lists that
  rebuild their whole content on every keystroke.
- Over-fetching: loading a whole file to display one line, or a whole
  dataset to show ten rows. Page, stream, or lazy-load.
- Unbounded caches and unbounded undo stacks. Cap them and evict.
- Logging in hot paths: string formatting and disk writes per frame add up.

## Verification

- Run the budget harness on every release candidate and record the numbers.
- Confirm a deliberate regression (a sleep on the main thread, a 10x data
  set) actually trips the budget check.
- Confirm idle CPU and memory are flat over a 30-minute idle session.
