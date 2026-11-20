# Git Workflows and Branching

<!-- system-index-depends: FileOperations.md -->

Git is the project's memory. This asset covers branching, merging, and
history discipline so the repository stays readable and recoverable.

## When to retrieve

- The user is setting up or changing a branching workflow.
- A merge went wrong, history is tangled, or a commit needs recovery.
- A release needs a clean, reviewable history.

## Workflow rules

- Main is always releasable. Work lands on main only through a reviewed
  branch, or through the project's explicit direct-to-main rule where one
  exists.
- Branches are short-lived and single-purpose. A branch that lives for
  weeks accumulates conflicts and hides progress.
- Commit messages state what changed and why, in the imperative mood.
  A message that only says "fix" helps no one later.
- Commits are reviewable units: each commit builds, and each commit does
  one thing. A commit that does five things cannot be reverted safely.
- Never rewrite history that others have pulled. Rebase is for private
  branches; shared history is append-only.

## Merge discipline

- Merge main into the branch often, so the final merge is small.
- Resolve conflicts by understanding both sides, not by picking one side
  wholesale.
- Verify the merge builds and the tests pass before declaring it done.
- Tag releases with a version and a note. A release without a tag is
  hard to find later.

## Recovery

- A bad commit is reverted with a revert commit, not by deleting history.
- A lost commit is usually recoverable from the reflog. Check there
  before assuming it is gone.
- A pushed mistake is fixed forward when possible. Rewriting a pushed
  branch requires coordinating everyone who pulled it.

## Common mistakes

- Committing secrets, credentials, or generated files. Check the ignore
  rules before the first commit, not after a leak.
- Working directly on main for a large change and discovering the
  conflict at the end.
- Merging without building, then discovering the break on main.
- Writing commit messages that describe the diff instead of the reason.

## Cross-references

- File operations and git safety: `FileOperations.md`
- Release notes and versioning: `ReleaseNotesAndVersioning.md`
- Code review: `CodeReviewSystemAsset.md`

## Limits

- Assist advises on workflow and recovery. It does not rewrite shared
  history, force-push, or perform destructive operations without an
  explicit instruction.
