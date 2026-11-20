# Crash-Log Analysis for Assist

<!-- system-index-depends: SymbolicationForAssist.md, Safeguards.md -->

A crash log is a post-mortem: what the process was doing when it died,
and why the system killed it. Assist reads crash logs to find the failing
frame, the exception, and the story around them.

## When to retrieve

- The user pastes a crash log or a `.ips` file.
- An app crashes on launch, on a specific action, or intermittently.
- A crash needs triage before anyone opens the source.

## What Assist reads first

- The exception type and code: the reason the system terminated the
  process. Different exception types point at different bug families.
- The termination reason and any attached diagnostic message.
- The crashed thread and its frames, top to bottom. The top frame is
  where execution died; the frames below it are how it got there.
- The binary images list: which binaries were loaded, their versions,
  and their UUIDs. A wrong version here explains many mysteries.
- The OS version, device model, and app version. A crash that only
  happens on one OS version is a different bug than a universal one.
- The last exception backtrace and any application-specific notes, when
  present.

## How to read a stack

- Start at the crashed frame, then walk down until the frames stop being
  system code and start being the app's code. The app's topmost frame is
  usually where the fix belongs.
- Distinguish the crashing call from the calling code. The crash address
  is where it died; the caller is often where the bad value came from.
- Watch for frames that repeat: recursion, or a loop that ran away.
- Symbolicate before interpreting. An unsymbolicated address is a number,
  not a name. See `SymbolicationForAssist.md`.

## How to report a crash

- Lead with the exception, the crashed thread's app frame, and the
  one-sentence story: what the app was doing when it died.
- Give the relevant frames, symbolicated, with offsets where symbols are
  missing.
- State what is known and what is not: a crash log shows the moment of
  death, not the minutes before it.
- Suggest the next step concretely: which function to inspect, which
  input to reproduce with, or which symbol file is missing.

## Common mistakes

- Blaming the top frame when the bug is in the caller.
- Treating a system frame as the app's bug without checking the frames
  below it.
- Symbolicating with the wrong build's symbols and reporting fiction.
- Assuming a crash log contains the full story. It contains the ending.

## Cross-references

- Symbolication: `SymbolicationForAssist.md`
- Crash reporting integration: `CrashReportingIntegration.md`
- Evidence handling: `EvidenceHandlingAndChainOfCustody.md`

## Limits

- Crash logs can contain user data, paths, and identifiers. Quote the
  minimum needed, and never repeat secrets or personal data found in one.
- A single crash log proves a single crash. Patterns need multiple logs.
