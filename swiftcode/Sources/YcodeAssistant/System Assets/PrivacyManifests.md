# Privacy Manifests

<!-- system-index-depends: AppSandboxSecurity.md -->

A privacy manifest (`PrivacyInfo.xcprivacy`) declares what an app and its
SDKs collect, why, and where it goes. Since Apple's privacy requirements,
an app without an accurate manifest is rejected at review or blocked from
using required-reason APIs. The manifest is a legal statement, not a formality.

## What goes in the manifest

- `NSPrivacyCollectedDataTypes`: each data type collected, whether it is
  linked to the user, used for tracking, and the purposes it serves.
- `NSPrivacyAccessedAPITypes`: each required-reason API the app uses, with
  the approved reason for each. This is the section most apps get wrong.
- `NSPrivacyTracking`: whether the app tracks the user across other
  companies' apps and websites.
- `NSPrivacyTrackingDomains`: the domains used for tracking, when tracking
  applies.

## Required-reason APIs

Apple lists APIs that require a declared reason. The common ones:

- `NSPrivacyAccessedAPICategoryFileTimestamp`: file creation/modification
  times. Reason: only to display them to the user, or to compute inside
  the app for the user's benefit.
- `NSPrivacyAccessedAPICategorySystemBootTime`: system uptime. Reason:
  measuring time inside the app, not fingerprinting.
- `NSPrivacyAccessedAPICategoryDiskSpace`: free disk space. Reason: only
  to tell the user whether an operation will fit.
- `NSPrivacyAccessedAPICategoryUserDefaults`: reading `UserDefaults`.
  Reason: only the app's own defaults, or shared defaults with its own
  app group.
- `NSPrivacyAccessedAPICategoryActiveKeyboards`: the active keyboard list.

For each API used, declare exactly one approved reason that matches what
the code actually does. A reason that does not match the code is a
rejection, and a missing declaration for an API the code calls is too.

## SDKs and third-party code

- Every third-party SDK bundled in the app needs its own privacy manifest,
  and the app's manifest must account for the data the SDK collects.
- When adding or updating a dependency, check whether its manifest changed.
  A dependency update can silently add a new collected data type.
- Audit the dependency's manifest against its actual behavior; do not
  copy its claims into the app manifest without checking.

## Keeping the manifest true

- Treat the manifest as code: review it in every PR that touches data
  collection, analytics, networking, or a required-reason API.
- Add a checklist item to the release process: does this release collect
  anything new, use any new API, or add any SDK? If yes, update the
  manifest first.
- Never collect data "just in case". Every collected type needs a purpose
  the user would recognize. Unused collection is a liability, not an asset.
- Keep the App Store privacy nutrition labels in sync with the manifest.
  They describe the same collection; a mismatch is a review problem.

## Verification

- Build the app and confirm `PrivacyInfo.xcprivacy` is in the bundle.
- Run the privacy report (Xcode's privacy report) and compare it against
  the manifest line by line.
- Search the codebase for required-reason API calls and confirm each has
  a declared reason.
- Confirm every bundled SDK ships its own manifest.
