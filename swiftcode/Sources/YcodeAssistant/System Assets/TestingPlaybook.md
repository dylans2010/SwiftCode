<!-- system-index-depends: BuildAndTesting.md, UnitTestingBestPractices.md -->
# TestingPlaybook — How to Test Code in SwiftCode

## When to test
- Every behavior change gets a test. Every bug fix starts with a failing regression test.
- Refactors require existing tests to pass before and after; add characterization tests when coverage is missing.

## Choosing the test type
| Need | Test type | Tools |
|---|---|---|
| Pure logic, models, parsing | Unit test (Swift Testing `@Test` / XCTest) | `swift_generate_test_skeleton`, `swiftpm_run_filtered_tests` |
| Components working together | Integration test with real implementations and temp directories | `swiftpm_run_filtered_tests` |
| User journeys | UI test with accessibility identifiers | `simctl_device_list`, xcodebuild test |
| Visual regressions | Snapshot/preview tests | `scan_preview_declarations` |
| Speed and memory | Performance test in Release | measure blocks |

## Writing good tests
- One behavior per test; name it after the behavior (`loginFailsWithExpiredToken`).
- Arrange–Act–Assert structure; assert outcomes, not implementation details.
- Use parameterized tests for input tables.
- Inject dependencies (clock, network, storage) through protocols; never call production services.
- No `sleep`; await conditions or use injected clocks.
- Tests must be independent and deterministic; seed any randomness.

## Running tests
1. Discover existing tests: `swift_list_test_functions` or `swiftpm_list_tests`.
2. Run the narrowest set first: `swiftpm_run_filtered_tests` with a filter.
3. Run the full suite before reporting completion.
4. When a test fails, read the full failure output, reproduce it, fix the cause (not the assertion), and re-run.

## Reporting
Report the exact commands, the number of tests run, passed and failed, and any tests you could not run with the reason. Never claim tests pass without running them.
