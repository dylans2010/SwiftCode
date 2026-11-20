<!-- system-index-depends: Skills.md -->
# SystemSkillsAndActions — Bundled Skills and Built-in Actions

## System Skills
SwiftCode ships 196 System Skills under `SC Skills/System Skills/<name>/SKILL.md`. They cover authentication (Keychain, OAuth PKCE, Sign in with Apple, biometrics), UI design (SwiftUI layout, design systems, accessibility, navigation), documentation (DocC, README, ADRs, changelogs), testing (Swift Testing, XCTest, UI tests, TDD, flaky tests), concurrency, networking, persistence, security, performance, architecture, platforms, debugging, Git collaboration, product work and agent behavior.

- Users install them from **Assist Settings → System Skills → Install System Skills**. They can uninstall all of them or individual skills there.
- Installation copies the skill folders into the SwiftCode skills library, which makes them discoverable by the skill index, the slash palette and every model.
- Each skill uses the standard SKILL.md format: YAML front matter (`name`, `description`, `category`, `tags`, `tools`, `version`) followed by When to use, Workflow, Rules, Verification, Avoid and Recommended tools sections.
- Models can list and read skills with `system_skill_catalog`. When the user's task matches a skill, follow its workflow and verification checklist.

## Built-in actions
| Command | Purpose |
|---|---|
| `/verify` | Build, test and review every uncommitted change |
| `/harden` | Security scan and fix secrets, crypto, transport and randomness issues |
| `/commit` | Draft a commit message from the staged diff |
| `/changelog` | Release notes since the last tag |
| `/a11y` | Accessibility pass on SwiftUI code |
| `/deps` | Dependency health, license and pinning audit |
| `/cleanup` | Remove debug prints, empty files, stale TODOs and dead code |
| `/spec` | Technical specification for a feature |
| `/swift6` | Swift 6 concurrency readiness |
| `/standup` | Summary of recent repository activity |
| `/coverage` | Find and fill test coverage gaps |
| `/optimize` | Fix performance anti-patterns |
| `/testgen` | Generate and run unit tests for a type or file |
| `/design` | UI design review against the design system |
| `/localize` | Move hardcoded strings into String Catalogs |
| `/readme` | Rewrite the README with verified commands |
| `/architecture` | Map modules, dependencies and data flow |
| `/triage` | Reproduce and localize a bug before fixing |
| `/modernize` | Migrate legacy APIs to modern Swift |
| `/release` | Release readiness checklist |

### Extended actions (50)
`/lint` `/format` `/deadcode` `/todos` `/secrets` `/crypto` `/concurrency` `/leaks` `/unwrap` `/errors` `/logging` `/api` `/docc` `/adr` `/diagram` `/upgrade` `/license` `/privacy` `/entitlements` `/signing` `/ci` `/buildfix` `/warnings` `/flaky` `/tdd` `/fakes` `/uitest` `/snapshot` `/benchmark` `/launch` `/rerender` `/darkmode` `/typography` `/ux-copy` `/states` `/navigation` `/swiftdata` `/coredata` `/networking` `/auth` `/sql` `/shellsafe` `/branches` `/history` `/conflicts` `/pr` `/risk` `/estimate` `/postmortem` `/modules`

### Action specifications
Every built-in action has a specification file in `SC Skills/<command>.md` (for example `SC Skills/verify.md`, `SC Skills/goal.md`). The spec describes syntax, preflight evidence, the ordered workflow, guidance to load, operational rules and the completion report. SwiftCode appends the spec to the action prompt, and the files are also indexed as built-in skills so any model can read them.

Each action runs read-only preflight tools (for example scans or git summaries), attaches their real output as workspace evidence, and then gives the model a numbered workflow and the System Assets to load. These actions complement `/goal`, `/interview`, `/learn`, `/boost`, `/teamwork`, `/compact` and `/schedule`.
