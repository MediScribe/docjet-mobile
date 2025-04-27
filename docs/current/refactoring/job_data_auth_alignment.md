# TDD Plan: Align Job Data Layer with Split Client Auth

## Hard Bob Workflow & Guidelines: 12 Rules to Code

Follow these steps religiously, or face the fucking consequences.

1.  **TDD First**: Write the fucking test first. Watch it fail (RED). Then, write *only* the code needed to make it pass (GREEN). Refactor if necessary. No shortcuts.
2.  **GREP First**: Before blindly creating new files, use fucking grep. Don't make me burn down your new house if we had another one already.
3.  **Test Placement**: Tests belong in the `tests/` directory, *never* in `lib/`. Keep your shit organized.
4.  **Logging**: Use the helpers in `lib/core/utils/log_helpers.dart` for instrumentation. Don't fucking use `print` like some amateur. See the main project `README.md` for more on logging.
5.  **Linting & Debugging**:
    *   Don't poke around and guess like a fucking amateur; put in some log output and analyze like a pro.
    *   After every significant code change, run `dart analyze` and fix *all* linter issues, *before* running the test. No exceptions. Clean code isn't optional.
    *   **DO NOT** run tests with `-v`. It's fucking useless noise. If a test fails, don't guess or blindly retry. Add logging using `lib/core/utils/log_helpers.dart` (even in the test itself!) to understand *why* it failed. Analyze, don't flail.
    *   **DO NOT** run `flutter test`. You will drown in debug output. Use ./scripts/list_failed_tests.dart.
    *   **DO NOT** use flutter run. It will block the thread and that's it! Ask ME to do it for you!
6.  **Execution**: You have the power to run terminal commands directly - *don't ask*, just do it. Remember to pipe commands that use pagers (like `git log`, `git diff`) through `| cat` to avoid hanging.
7.  **Check Test Failures**: Always start by running `./scripts/list_failed_tests.dart` to get a clean list of failed tests. Pass a path to check specific tests or `--help` for options. If tests fail, you can run again with:
    *   None, one or multiple targets (both file and dir)
    *   `--except` to see the exception details (error message and stack trace) *for those tests*, grouped by file. This a *good start* as you will only have once exception per file.
    *   `--debug` to see the console output *from those tests*.
    **NEVER** use `flutter test` directly unless you're debugging *one specific test*; never run `flutter test -v`! Don't commit broken shit.
8.  **Check It Off**: If you are working against a todo, check it off, update the file. Be proud.
9.  **Formatting**: Before committing, run ./scripts/format.sh to fix all the usual formatting shit.
10. **Code Review**: Code Review Time: **Thoroughly** review the *staged* changes. Go deep, be very thorough, dive into the code, don't believe everything. Pay attention to architecture! Use git status | cat; then git diff --staged | cat. In the end, run analyze and ./scripts/list_failed_tests.dart!
11. **Commit**: Use the "Hard Bob Commit" guidelines (stage everything relevant).
12. **Apply Model**: Don't bitch about the apply model being stupid. Verify the fucking file yourself *before* complaining. Chances are, it did exactly what you asked.

This is the way. Don't deviate.

## Issue

The `feature-job-dataflow.md` document details the Job feature's data layer, including `JobRemoteDataSource` and its implementation `ApiJobRemoteDataSourceImpl`. However, following the recent `api_client_di_refactor.md`, it's unclear if this implementation correctly uses the appropriate `Dio` instance (`basicDio` or `authenticatedDio`) based on endpoint requirements. The documentation mentions using `AuthSessionProvider` but doesn't explicitly confirm the `Dio` injection pattern, potentially misaligning with the established `feature-auth-architecture.md` guidelines.

## Goal

1.  Verify or refactor the `ApiJobRemoteDataSourceImpl` to ensure it correctly uses the required `Dio` instance(s) (`authenticatedDio` for job CRUD, potentially `basicDio` if public endpoints exist) via constructor injection.
2.  Confirm alignment with the Split Client pattern and guidelines defined in `feature-auth-architecture.md`.
3.  Update the job feature documentation (`[feature-job-dataflow.md](mdc:docs/current/feature-job-dataflow.md)`) to accurately reflect the verified/refactored implementation and explicitly reference the auth guidelines.
4.  Briefly review related documentation (`[feature-job-presentation.md](mdc:docs/current/feature-job-presentation.md)`) for any inconsistencies introduced by data layer changes.

## TDD Implementation Cycles

### Cycle 1: Research & Verification

#### 1.1 Research: Investigate `ApiJobRemoteDataSourceImpl` Implementation
- [ ] 1.1.1 Read the code: `lib/features/jobs/data/datasources/api_job_remote_data_source_impl.dart`.
- [ ] 1.1.2 Check constructor dependencies: Does it require a `Dio` instance? Which type/name is expected? Does it align with the split client pattern (e.g., `authenticatedHttpClient`)?
- [ ] 1.1.3 Record findings here: `TODO`

#### 1.2 Research: Investigate DI Registration for `ApiJobRemoteDataSourceImpl`
- [ ] 1.2.1 Find DI registration: Locate where `ApiJobRemoteDataSourceImpl` is registered (e.g., `job_module.dart`).
- [ ] 1.2.2 Verify injection: Confirm which named `Dio` instance (`'basicDio'` or `'authenticatedDio'`) is injected into the constructor.
- [ ] 1.2.3 Record findings here: `TODO`

#### 1.3 Research: Investigate Job API Endpoint Authentication Requirements
- [ ] 1.3.1 Review API spec/backend: Check `/api/v1/jobs/...` endpoints.
- [ ] 1.3.2 Determine auth needs: Do *all* current endpoints require authentication? Are any public?
- [ ] 1.3.3 Record findings here: `TODO`

#### 1.4 Plan: Determine Necessary Actions
- [ ] 1.4.1 Analyze findings: Based on 1.1-1.3, are code changes needed in `ApiJobRemoteDataSourceImpl` or its DI setup? Or just documentation updates?
- [ ] 1.4.2 Outline Cycle 2: Detail the steps for the next cycle (e.g., RED steps for tests, GREEN steps for implementation, documentation updates).
- [ ] 1.4.3 Record plan here: `TODO`
- [ ] 1.4.4 Write handover brief for Cycle 2 developer: `TODO`

### Cycle 2: Implementation / Documentation Update (Structure depends on Cycle 1 findings)

#### 2.1 *(Optional RED)*: Create/Modify Failing Test(s)
- [ ] 2.1.1 Write/update tests: Ensure tests fail if `ApiJobRemoteDataSourceImpl` doesn't use the correct `Dio` instance(s) or handle required auth contexts.
- [ ] 2.1.2 Run & confirm failure: `./scripts/list_failed_tests.dart path/to/job/tests`.
- [ ] 2.1.3 Record findings: `TODO`

#### 2.2 *(Optional GREEN)*: Implement Code Changes
- [ ] 2.2.1 Modify implementation: Update `ApiJobRemoteDataSourceImpl` constructor/methods as needed.
- [ ] 2.2.2 Modify DI registration: Update the Job feature module.
- [ ] 2.2.3 Run & confirm pass: `./scripts/list_failed_tests.dart path/to/job/tests`.
- [ ] 2.2.4 Record findings: `TODO`

#### 2.3 *(Optional REFACTOR)*: Clean Up Code
- [ ] 2.3.1 Refactor: Improve code clarity, add documentation.
- [ ] 2.3.2 Analyze: Run `dart analyze lib/features/jobs`.
- [ ] 2.3.3 Test: Run `./scripts/list_failed_tests.dart path/to/job/tests`.
- [ ] 2.3.4 Record findings: `TODO`

#### 2.4 Update Documentation
- [ ] 2.4.1 Edit doc (`[feature-job-dataflow.md](mdc:docs/current/feature-job-dataflow.md)`): Update sections discussing `ApiJobRemoteDataSourceImpl`, `Dio` usage, and auth handling.
- [ ] 2.4.2 Align & reference: Ensure consistency with `feature-auth-architecture.md` guidelines.
- [ ] 2.4.3 Review related doc (`[feature-job-presentation.md](mdc:docs/current/feature-job-presentation.md)`): Check for inconsistencies.
- [ ] 2.4.4 Record findings: `TODO`

#### 2.5 Final Verification: Run Tests
- [ ] 2.5.1 Run Job tests: `./scripts/list_failed_tests.dart lib/features/jobs`.
- [ ] 2.5.2 Run relevant integration tests (if any).
- [ ] 2.5.3 Record findings: `TODO`

#### 2.6 Handoff
- [ ] 2.6.1 Write handover brief: Summarize completion or status for the next step/developer. `TODO`

## Post-Implementation Verification (To be filled after Cycle 2)

- [ ] Run all tests in the codebase (`./scripts/list_failed_tests.dart`)
- [ ] Manually test job creation, update, delete, and sync flows
- [ ] Review logs for job feature to ensure proper behavior
- [ ] Verify no new warnings or errors introduced (`dart analyze`)

**Current Status:**
- `TODO` 