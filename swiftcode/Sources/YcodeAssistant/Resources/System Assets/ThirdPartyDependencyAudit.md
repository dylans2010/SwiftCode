# Third-Party Dependency Audit

<!-- system-index-depends: Safeguards.md, SPMConfigurationDeepDive.md -->

Every dependency is code the user did not write, running with the app's
privileges. This asset covers how Assist audits dependencies for license,
security, and maintenance risk before they are added, and on a schedule
afterward.

## When to retrieve

- The user is considering adding a dependency.
- A dependency update, vulnerability notice, or license question arises.
- A periodic audit of the dependency tree is due.

## What an audit checks

- License: the declared license, whether it is compatible with the app's
  distribution, and whether its obligations (attribution, source
  disclosure) are met.
- Maintenance: last release date, open issue count and responsiveness,
  and whether the project is actively maintained or abandoned.
- Scope: what the dependency actually does versus what the app needs. A
  large library for one small function is a smell.
- Transitive dependencies: what the dependency pulls in. The audit covers
  the whole tree, not just the top level.
- Permissions and capabilities: network access, file access, and any
  privileged operation the dependency performs.
- Build impact: build time, binary size, and minimum OS version effects.

## How to report an audit

- One row per dependency: version, license, last release, risk level, and
  the reason for the rating.
- Separate hard blockers (incompatible license, known vulnerability with
  no fix) from cautions (unmaintained, over-broad scope).
- Name the alternative for each blocker: a maintained fork, a smaller
  library, or a first-party implementation.
- Say what was not checked: a dependency with no public audit trail is a
  finding, not a pass.

## Ongoing discipline

- Pin versions. A floating version is an unreviewed change.
- Review updates before adopting them, and read the changelog for
  breaking changes and new permissions.
- Remove dependencies that are no longer used. Dead dependencies still
  carry risk.
- Re-audit on a schedule, and immediately when a vulnerability is
  disclosed for anything in the tree.

## Common mistakes

- Auditing only the direct dependencies and missing the transitive tree.
- Accepting a license without reading its obligations.
- Adding a dependency for a function the platform already provides.
- Treating popularity as safety. Popular libraries have vulnerabilities
  too.

## Cross-references

- SPM configuration: `SPMConfigurationDeepDive.md`
- Secrets management: `SecretsManagementInApps.md`
- Binary size: `BinarySizeOptimization.md`

## Limits

- Assist audits from public information: licenses, releases, advisories,
  and source. It cannot audit closed-source dependencies beyond their
  declared behavior.
