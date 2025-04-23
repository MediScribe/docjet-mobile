# User ID Injection Architecture Fix

## Hard Bob Workflow & Guidelines

Follow these steps religiously, or face the fucking consequences.

1. **TDD First**: Write the fucking test first. Watch it fail (RED). Then, write *only* the code needed to make it pass (GREEN). Refactor if necessary. No shortcuts.
2. **GREP First**: Before blindly creating new files, use fucking grep. Don't make me burn down your new house if we had another one already.
3. **Test Placement**: Tests belong in the `tests/` directory, *never* in `lib/`. Keep your shit organized.
4. **Logging**: Use the helpers in `log_helpers.dart` for instrumentation. Don't fucking use `print` like some amateur.
5. **Linting & Debugging**: 
   * After every significant code change, run `dart analyze` and fix *all* linter issues, *before* running the test. No exceptions. Clean code isn't optional.
   * **DO NOT** run tests with `-v`. If a test fails, don't guess or blindly retry. Add logging to understand *why* it failed. Analyze, don't flail.
6. **Execution**: You have the power to run terminal commands directly - *don't ask*, just do it. Pipe pager commands through `| cat` to avoid hanging.
7. **Check Test Failures**: Always start by running `./scripts/list_failed_tests.dart` to get a clean list of failed tests.
8. **Check It Off**: If you are working against a todo, check it off, update the file. Be proud.
9. **Formatting**: Before committing, run `./scripts/format.sh` to fix all the usual formatting shit.
10. **Commit**: Use the "Hard Bob Commit" guidelines (stage everything relevant).
11. **Apply Model**: Don't bitch about the apply model being stupid. Verify the fucking file yourself *before* complaining.

This is the way. Don't deviate.

## The Architecture Violation

We have a critical architectural flaw: UI components are directly passing `userId` as a parameter down through use cases to repositories. This violates clean architecture principles in several ways:

1. **Violates Dependency Rule**: Domain layer shouldn't know about UI or presentation details
2. **Breaks Isolation**: Business logic becomes dependent on authentication context from outside
3. **Complicates Testing**: Use cases need unnecessary test parameters
4. **Ruins Single Responsibility**: Components have to shuttle IDs they shouldn't care about

The **correct approach** is to inject a domain-level `AuthSessionProvider` that provides the currently authenticated user's ID to the repository layer without the UI needing to pass it explicitly.

We've implemented the provider classes, but we did it ass-backwards without TDD and without properly updating the downstream components. We need to fix this shit with a proper bottom-up approach.

## TDD Fix Plan

- [ ] **INVESTIGATION: Map Current User ID Flow**
    - [ ] Grep codebase for `userId` parameters to identify all violations
    - [ ] Run `grep -r "userId" --include="*.dart" lib/features/jobs/` to find all places
    - [ ] Document all components that need to be updated
    - [ ] Identify specific UI components passing user IDs downstream (e.g., `job_list_playground.dart`)

- [ ] **TDD for Domain Layer (Most Isolated)**
    - [ ] Write failing test for updated `JobRepository` interface without `userId` in `createJob()`
    - [ ] Modify the interface in `job_repository.dart` to remove the parameter
    - [ ] Write failing test for `CreateJobUseCase` without `userId` parameter
    - [ ] Update `CreateJobParams` class to remove userId
    - [ ] Modify `call()` implementation to not pass userId to repository

- [ ] **TDD for Domain Authentication Component**
    - [ ] Verify existing `AuthSessionProvider` interface tests are comprehensive
    - [ ] Add missing tests for edge cases (no user authentication)
    - [ ] Check alignment with domain needs (do we need additional methods?)

- [ ] **TDD for Repository Implementation** 
    - [ ] Write failing test for `JobRepositoryImpl` constructor with `AuthSessionProvider`
    - [ ] Test that `createJob()` retrieves userId from provider not parameters
    - [ ] Test authentication validation behavior
    - [ ] Test error propagation when no user is authenticated
    - [ ] Update `JobRepositoryImpl` to match the tests

- [ ] **TDD for Infrastructure Layer**
    - [ ] Review existing `SecureStorageAuthSessionProvider` implementation and tests
    - [ ] Add missing tests for behavior with `AuthService`
    - [ ] Fix any implementation issues discovered

- [ ] **TDD for Services Layer**
    - [ ] Update tests for `JobWriterService` removing userId parameter
    - [ ] Check tests for proper error handling
    - [ ] Modify `JobWriterService.createJob()` implementation 

- [ ] **Integration Testing**
    - [ ] Write integration test for `JobRepository` -> `AuthSessionProvider` flow
    - [ ] Test end-to-end job creation without explicit userId
    - [ ] Test authentication error flow
    - [ ] Test recovery after authentication

- [ ] **UI Layer and DI Container**
    - [ ] Update `job_list_playground.dart` to remove userId parameter
    - [ ] Verify `SecureStorageAuthSessionProvider` is registered in DI container
    - [ ] Update affected component registrations with new dependencies

- [ ] **Documentation and Architecture Updates**
    - [ ] Update architecture docs to explain user context handling
    - [ ] Document fixes in `job_dataflow.md`
    - [ ] Add notes about authentication context to `job_presentation_layer.md`

- [ ] Documentation Updates
  - [ ] Update `docs/current/architecture.md` under "Authentication" to describe domain‑level `AuthSessionProvider`
  - [ ] Update `docs/current/job_dataflow.md` to note that `ApiJobRemoteDataSource` now uses `AuthSessionProvider` for user context
  - [ ] Update `docs/current/job_presentation_layer.md` to show Cubits and UseCases no longer require a userId parameter 