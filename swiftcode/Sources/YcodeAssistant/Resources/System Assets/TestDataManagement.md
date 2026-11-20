# Test Data Management

<!-- system-index-depends: UnitTestingBestPractices.md -->

Tests are only as trustworthy as their data. Test data must be small,
explicit, deterministic, and owned by the test that uses it. Shared,
mutable, or production-shaped fixtures are how test suites become slow
and flaky.

## Principles

- Each test builds its own data. A test that depends on a fixture another
  test mutated is a test that fails when run in a different order.
- Keep fixtures minimal: the smallest input that exercises the behavior.
  A 500-line JSON blob for a test that checks one field hides the intent.
- Deterministic data only. No random values, no current dates, no network.
  If the code under test needs "now", inject a clock.
- Name fixtures for what they represent (`expiredToken`, `emptyProject`),
  not for their format (`test1.json`).

## Fixtures and factories

- Prefer small factory functions in the test target over fixture files:
  `makeProject(name:)` beats a directory of JSON files.
- When a fixture file is genuinely needed (a real file format, a large
  payload), keep it in the test target's resources and load it by name.
- One fixture file per scenario. A single file reused by twenty tests
  becomes untouchable: nobody knows which tests depend on which part.
- Keep fixtures in the test target, never in the app target. Test data
  must not ship in the product.

## Databases and files in tests

- Tests that touch a database or the file system must use a fresh,
  isolated store per test: an in-memory database or a unique temporary
  directory created in `setUp` and removed in `tearDown`.
- Never point tests at the user's real data, the app's real database, or
  a shared directory. A test that deletes the wrong folder is a disaster.
- Seed the store inside the test, not in a global setup. Global seeding
  couples every test to every other test's data.

## Secrets and realistic data

- Never use real credentials, real tokens, or real user data in tests.
  Use obviously fake values (`test@example.com`, `sk-test-...`).
- Never commit a fixture that contains a real API key, even a revoked one.
  Scanners and reviewers treat committed secrets as live.
- For realistic shapes (names, addresses, dates), use fixed example values
  rather than generated random ones so failures are reproducible.

## Performance and scale

- Keep the suite fast by keeping data small. A test that loads a 10MB
  fixture to check a string comparison is paying 10MB for nothing.
- Performance tests use their own larger datasets, clearly marked, and
  run separately from the unit suite.
- Clean up after every test. A suite that leaves temp files and databases
  behind pollutes the next run.

## Verification

- Run the suite in random order and in parallel; it must stay green.
- Run a single test in isolation; it must pass without the rest of the suite.
- Confirm no fixture file contains a real secret or real user data.
