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

## TDD Fix Plan (do only one main todo at a time; then ask user for review and commit!)

1. [ ] **INVESTIGATION: Map Current User ID Flow**
    1.1. [ ] Grep codebase for `userId` parameters to identify all violations
    1.2. [ ] Run `grep -r "userId" --include="*.dart" lib/features/jobs/` to find all places
    1.3. [ ] Document all components that need to be updated
    1.4. [ ] Identify specific UI components passing user IDs downstream (e.g., `job_list_playground.dart`)

    **Investigation Findings:**
    * `userId` is being passed from UI in `job_list_playground.dart` down through the layers
    * `CreateJobUseCase` and `CreateJobParams` both contain `userId` parameter 
    * `JobRepository` interface defines a `createJob` method requiring `userId` parameter
    * `JobRepositoryImpl` passes this parameter to `JobWriterService`
    * `JobWriterService` uses it when constructing a new `Job` entity
    * `JobRemoteDataSource` interface and `ApiJobRemoteDataSourceImpl` require `userId` for API calls
    * Existing `AuthSessionProvider` and `SecureStorageAuthSessionProvider` implementation are already in place to handle user context

2. [ ] **TDD for Domain Layer (Most Isolated)**
    2.1. [ ] Write failing test for updated `JobRepository` interface without `userId` in `createJob()`
    2.2. [ ] Modify the interface in `job_repository.dart` to remove the parameter
    2.3. [ ] Write failing test for `CreateJobUseCase` without `userId` parameter
    2.4. [ ] Update `CreateJobParams` class to remove userId
    2.5. [ ] Modify `call()` implementation to not pass userId to repository

3. [ ] **TDD for Repository Implementation** 
    3.1. [ ] Write failing test for `JobRepositoryImpl` constructor with `AuthSessionProvider`
    3.2. [ ] Test that `createJob()` retrieves userId from provider not parameters
    3.3. [ ] Update `JobRepositoryImpl` to inject `AuthSessionProvider` and use it in the `createJob()` method

4. [ ] **Fix Test Implementations**
    4.1. [ ] Generate new mocks for test files
    4.2. [ ] Update `CreateJobParams` usage in test files
    4.3. [ ] Add mock `AuthSessionProvider` to test setup
    4.4. [ ] Update DI container for tests
    4.5. [ ] Remove `userId` parameter from UI layer

5. [ ] **TDD for Services Layer**
    5.1. [ ] Write failing test for `JobWriterService` to get `userId` from injected provider
    5.2. [ ] Add `AuthSessionProvider` to `JobWriterService` constructor
    5.3. [ ] Modify `JobWriterService` implementation to use injected provider
      5.3.1. [ ] Move `getCurrentUserId()` call outside the try/catch block to properly throw authentication errors
      5.3.2. [ ] Remove `userId` parameter from `createJob()` method
      5.3.3. [ ] Updated error handling for authentication errors
    5.4. [ ] Add `getCurrentUserId()` method to `AuthService` interface
    5.5. [ ] Implement `getCurrentUserId()` in `MockAuthService` and `AuthServiceImpl`
    5.6. [ ] Enhance `SecureStorageAuthSessionProvider` to initialize from `AuthService`
    5.7. [ ] Update tests for `SecureStorageAuthSessionProvider` to handle the constructor changes
    5.8. [ ] Update `injection_container.dart` to provide `AuthSessionProvider` to `JobWriterService`
    5.9. [ ] Fix test implementations for `JobRepositoryImpl` and integration tests
    5.10. [ ] Update E2E test setup helpers to include `AuthSessionProvider` in service registration
    5.11. [ ] Update tests for Job Remote Data Source to use AuthSessionProvider
      5.11.1. [ ] Create test file to verify `JobRemoteDataSource` interface no longer requires `userId`
      5.11.2. [ ] Create tests to verify `ApiJobRemoteDataSourceImpl` uses `AuthSessionProvider` correctly
    5.12. [ ] Update Remote Data Source implementation
      5.12.1. [ ] Update interface to remove `userId` parameter from `createJob` method
      5.12.2. [ ] Update implementation to inject and use `AuthSessionProvider`
      5.12.3. [ ] Add proper error handling for authentication errors

6. [ ] **Fix Exception Handling in Data Source Implementation**
    6.1. [ ] Update `_createJobFormData` method to handle authentication errors consistently
    6.2. [ ] Update test to correctly validate exception handling behavior
    6.3. [ ] Ensure proper ApiException wrapping for all error cases
    6.4. [ ] Update e2e test setups to properly mock AuthSessionProvider
      6.4.1. [ ] Fix mocks in job_sync_deletion_failure_e2e_test.dart to correctly stub createJob without userId
      6.4.2. [ ] Fix mocks in job_sync_reset_failed_e2e_test.dart to handle updated method signature
      6.4.3. [ ] Fix mocks in job_sync_retry_e2e_test.dart to handle updated method signature
      6.4.4. [ ] Fix mocks in job_sync_creation_failure_e2e_test.dart to handle updated method signature
    6.5. [ ] Ensure expect statements check for correct status state

7. [ ] **TDD for Domain Authentication Component**
    7.1. [ ] Verify existing `AuthSessionProvider` interface tests are comprehensive
    7.2. [ ] Add missing tests for edge cases (no user authentication)
    7.3. [ ] Check alignment with domain needs (do we need additional methods?)

8. [ ] **TDD for Repository Implementation (continued)** 
    8.1. [ ] Test authentication validation behavior
    8.2. [ ] Test error propagation when no user is authenticated

9. [ ] **TDD for Infrastructure Layer**
    9.1. [ ] Review existing `SecureStorageAuthSessionProvider` implementation and tests
    9.2. [ ] Add missing tests for behavior with `AuthService`
    9.3. [ ] Fix any implementation issues discovered

10. [ ] **Integration Testing**
    10.1. [ ] Write integration test for `JobRepository` -> `AuthSessionProvider` flow
    10.2. [ ] Test end-to-end job creation without explicit userId
    10.3. [ ] Test authentication error flow
    10.4. [ ] Test recovery after authentication

11. [ ] **UI Layer and DI Container**
    11.1. [ ] Update `job_list_playground.dart` to remove userId parameter
    11.2. [ ] Verify `SecureStorageAuthSessionProvider` is registered in DI container
    11.3. [ ] Update affected component registrations with new dependencies

12. [ ] **Documentation and Architecture Updates**
    12.1. [ ] Update architecture docs to explain user context handling
    12.2. [ ] Document fixes in `job_dataflow.md`
    12.3. [ ] Add notes about authentication context to `job_presentation_layer.md`

13. [ ] **Documentation Updates**
    13.1. [ ] Update `docs/current/architecture.md` under "Authentication" to describe domain‑level `AuthSessionProvider`
    13.2. [ ] Update `docs/current/job_dataflow.md` to note that `ApiJobRemoteDataSource` now uses `AuthSessionProvider` for user context
    13.3. [ ] Update `docs/current/job_presentation_layer.md` to show Cubits and UseCases no longer require a userId parameter 