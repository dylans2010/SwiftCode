# Search and Spotlight Integration

<!-- system-index-depends: SwiftUIArchitecture.md -->

Search inside the app and search from Spotlight are two faces of the same
problem: the user knows what they want and does not remember where it lives.
Both need an index, a ranking, and a fast path to the result.

## In-app search

- Search as the user types, debounced by ~150ms, and cancel the previous
  search when a new keystroke lands. A stale result is worse than a slow one.
- Rank exact matches first, then prefix matches, then substring matches,
  then fuzzy matches. Never present results in file-system order.
- Highlight the matched text in each result so the user can see why it
  matched.
- Keep the search field focused and keyboard navigable: arrow keys move,
  Return opens, Escape clears and returns focus.
- Search the content, not just titles. Index the body text, tags, and
  metadata the user actually remembers.
- Cap the result list and say so ("showing 50 of 312"). An unbounded list
  is a frozen UI waiting to happen.

## Spotlight with Core Spotlight

- Index user content with `CSSearchableItem` through `CSSearchableIndex`.
  Each item needs a stable unique identifier, a title, a content
  description, and keywords the user would actually type.
- Set a `thumbnailURL` or `thumbnailData` where a visual helps; a bare
  text result is harder to recognize.
- Update the index when content changes and delete items when content is
  deleted. A Spotlight result that opens a deleted document is a broken
  promise.
- Handle `NSUserActivity` with `CSSearchableItemActionType` in the app
  delegate or scene: open the exact item, not the app's front page.
- Index on a background queue. Indexing is I/O and string work; it must
  never block the main thread.

## NSUserActivity and continuity

- Publish an `NSUserActivity` for the user's current document or view so
  Handoff and Spotlight can resume it.
- Keep the activity's `userInfo` minimal: an identifier the app can
  resolve, not the document itself.
- Invalidate the activity when the user moves on; a stale activity
  resumes the wrong thing.

## Privacy and scope

- Never index content the user has marked private, encrypted, or excluded
  from search. Spotlight indexing is a copy of the content outside the app.
- Respect the user's choice: if they disable Spotlight indexing in
  Settings, delete the existing index entries.
- Do not index credentials, tokens, or file paths that reveal structure
  the user did not intend to publish.

## Verification

- Create, rename, and delete content and confirm Spotlight follows.
- Search with the app closed and confirm the result opens the right item.
- Confirm in-app search cancels cleanly and never shows stale results.
- Confirm private content never appears in a Spotlight query.
