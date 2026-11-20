# Crash Reporting Integration

<!-- system-index-depends: Safeguards.md, CrashLogAnalysisForAssist.md -->

Crash reporting turns crashes in the wild into actionable reports. This
asset covers how Assist integrates a reporter, keeps it honest, and reads
what it produces.

## When to retrieve

- The user is adding crash reporting to an app.
- Crash reports are missing, duplicated, or unactionable.
- A crash-reporting setup needs a privacy review.

## Integration rules

- The reporter initializes before anything that can crash, and as early
  in launch as the app allows. A late reporter misses early crashes.
- Symbols upload with every release, matched by UUID to the shipped
  build. A report without matching symbols is an address list, not a
  diagnosis. See `SymbolicationForAssist.md`.
- The reporter sends the minimum needed: stack, exception, OS and app
  version, and a session identifier. It does not send user content, file
  contents, or secrets.
- The user can opt out, and opting out is honored completely, including
  for crashes that already happened.
- Test the pipeline end to end before shipping: force a crash in a test
  build and confirm the report arrives symbolicated.

## Reading reports

- Group by the crashing frame and the exception, not by the raw count.
  One bug can produce many reports.
- Prioritize by reach and severity: crashes on launch and crashes on a
  common path outrank rare edge crashes.
- Read the report's context: OS version, device, app version, and whether
  the crash is new in this release or old.

## Privacy rules

- Crash reports are diagnostic data, and they are subject to the app's
  privacy promises. If the privacy manifest says no tracking, the
  reporter must not track.
- Scrub user data from reports before they leave the device where
  possible: paths, identifiers, and free-text fields.
- Retain reports only as long as they are useful, and say how long that
  is.

## Common mistakes

- Shipping without uploading symbols, then wondering why reports are
  unreadable.
- Treating the report count as the bug count.
- Collecting device identifiers or user content in reports without
  disclosure.
- Initializing the reporter after the code that crashes first.

## Cross-references

- Crash-log analysis: `CrashLogAnalysisForAssist.md`
- Symbolication: `SymbolicationForAssist.md`
- Privacy manifests: `PrivacyManifests.md`

## Limits

- A reporter shows crashes that were reported. It cannot show crashes on
  devices that never send, or crashes the reporter itself missed.
- Assist integrates and interprets; it does not choose a vendor for the
  user.
