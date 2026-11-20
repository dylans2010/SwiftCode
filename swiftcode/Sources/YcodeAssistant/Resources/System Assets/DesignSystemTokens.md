# Design System Tokens

<!-- system-index-depends: SwiftUIArchitecture.md, AssetCatalogManagement.md -->

Design tokens are the named values behind a consistent interface: colors,
type sizes, spacing, radii, and shadows. This asset covers how Assist
designs a token system that survives dark mode, accessibility sizes, and
new features.

## When to retrieve

- The user is building or cleaning up a design system.
- Colors or spacing are inconsistent across screens.
- A new theme, dark mode, or accessibility requirement needs support.

## Token principles

- Tokens have semantic names, not visual ones. A token is called
  "surface" or "primary action", not "light gray" or "blue".
- Every token has a light and a dark value. A token with only one value
  is a bug waiting for dark mode.
- Type tokens are scales, not one-off sizes. Body, title, caption, and
  their weights form a system.
- Spacing tokens are a small set of steps, not arbitrary numbers. Four or
  five steps cover most layouts.
- Tokens live in one place. A color defined in three files is three
  colors that will drift.

## What Assist checks

- Every hard-coded color, size, or spacing value in the UI, and whether a
  token should replace it.
- Contrast in both appearances, and at larger accessibility type sizes.
- Whether semantic colors adapt to the system appearance automatically or
  need manual handling.
- Whether the token set covers the states a control needs: default,
  hover, pressed, disabled, and focused.

## How to introduce tokens

- Start with the tokens the app already uses implicitly: the three or
  four colors and sizes that appear everywhere.
- Name them semantically and document what each one is for.
- Migrate one surface at a time, verifying appearance in both modes at
  each step.
- Delete the hard-coded value when the token replaces it. A token and a
  duplicate literal will diverge.

## Common mistakes

- Naming tokens after their current appearance, which breaks when the
  appearance changes.
- Defining tokens per screen instead of per system.
- Forgetting disabled and focused states until a review catches them.
- Using a token for a one-off value that is not part of the system.

## Cross-references

- SwiftUI architecture: `SwiftUIArchitecture.md`
- Asset catalogs: `AssetCatalogManagement.md`
- Accessibility audit: `AccessibilityAuditAndRemediation.md`

## Limits

- Tokens are a system, not a style. Assist defines the structure and the
  discipline; the visual choices remain the user's.
