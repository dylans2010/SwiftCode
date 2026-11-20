# Release Notes and Versioning

<!-- system-index-depends: GitWorkflowsAndBranching.md -->

Versioning and release notes are how users understand what changed and
whether to update. A version number is a promise about compatibility; a
release note is the evidence for it.

## Semantic versioning

- `MAJOR.MINOR.PATCH`: MAJOR for breaking changes, MINOR for new features
  that stay compatible, PATCH for bug fixes only.
- A breaking change is any change that forces the user to do something
  different: a removed feature, a changed file format, a dropped OS.
- Never reuse a version number. Once a version ships, its meaning is fixed.
- Pre-release versions carry a suffix (`1.4.0-beta.1`) and are never
  promoted to release by renaming; they get a new release version.
- Keep the marketing version and the build number distinct: the version
  is what the user sees, the build number is what distinguishes builds
  of the same version.

## What goes in a release

- A tag on the exact commit that shipped, named after the version.
- A build produced from that tag, not from a nearby commit.
- Release notes written from the merged changes, not from memory.
- A check that the previous version's data migrates cleanly to this one.

## Writing release notes

- Lead with what the user gains, in their language, not the internal
  ticket name.
- Group notes: New, Improved, Fixed. One line per change, in present
  tense, naming the affected feature.
- Name breaking changes explicitly and say what the user must do.
- Credit contributors where the project does that.
- Never write "bug fixes and improvements" as the whole note. If the
  release genuinely contains only minor fixes, say which ones matter.
- Keep a `CHANGELOG.md` in the repo as the durable record, and derive
  the App Store "What's New" text from it.

## The release checklist

- Version bumped in the project, the Info.plist, and the changelog.
- All tests pass on a clean checkout of the tagged commit.
- The app launches cold, opens existing user data, and migrates it.
- Privacy manifest and entitlements reviewed for this release's changes.
- Release notes reviewed by someone who did not write the code.
- The tag is pushed and the release artifact is attached to it.

## Hotfixes

- A hotfix branches from the release tag, not from main. Main may contain
  unreleased work that must not ship in the fix.
- The hotfix gets its own PATCH version and its own notes.
- Merge the hotfix back to main immediately after shipping so the fix is
  not lost in the next release.

## Verification

- Install the previous release, open real user data, then update in place.
- Confirm the version string in the app matches the tag and the notes.
- Confirm the changelog entry matches what actually shipped.
