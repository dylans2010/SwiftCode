# App Store Submission Checklist

<!-- system-index-depends: CodeSigningAndNotarization.md, BuildAndTesting.md -->

Submission is a checklist, not a hope. This asset covers what Assist
verifies before an app goes to App Store Connect, so a rejection is a
surprise instead of a routine.

## When to retrieve

- The user is preparing a release build for the App Store.
- A submission was rejected and the cause needs triage.
- Release hygiene needs a pre-flight pass.

## Pre-submission checks

- The release build is built from a clean checkout on the release branch,
  with no debug-only code paths active.
- Version and build numbers are bumped and match the release plan. A
  reused build number is a silent failure.
- Signing uses the distribution identity and the correct provisioning
  profile. Development signing on a submission is a rejection.
- Entitlements match the app's declared capabilities, and every
  entitlement-gated feature has its capability enabled in App Store
  Connect.
- The privacy manifest is present and accurate, and the App Privacy
  answers match it. See `PrivacyManifests.md`.

## Metadata checks

- Screenshots match the current UI and the declared device sizes.
- The description, keywords, and category describe the app that was
  built, not the app that was planned.
- Support and privacy URLs resolve and point at the right pages.
- In-app purchases and subscriptions are configured and tested in the
  sandbox before submission. See `InAppPurchaseAndStoreKit.md`.

## Common rejection causes

- Placeholder content, dead links, or unfinished UI.
- Requesting a permission the app does not explain or use.
- A capability declared in entitlements but not in the submission.
- A crash on review hardware that never appeared on the developer's
  machine.
- Misleading metadata: screenshots or text that promise what the app does
  not do.

## After a rejection

- Read the rejection text first, not the forums. It usually names the
  guideline and the evidence.
- Reproduce the reviewer's finding on a clean install before changing
  anything.
- Fix the finding, not the guideline. A narrow fix with a clear note
  resolves faster than a redesign.
- Record the rejection and the fix with the release, so the next release
  does not repeat it.

## Cross-references

- Code signing: `CodeSigningAndNotarization.md`
- Privacy manifests: `PrivacyManifests.md`
- Release notes and versioning: `ReleaseNotesAndVersioning.md`

## Limits

- Assist checks the app and its metadata; it cannot predict review
  outcomes. Guidelines change, and reviewers apply judgment.
- Assist never submits on the user's behalf without an explicit instruction
  to do so.
