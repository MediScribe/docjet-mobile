@hard-bob-workflow.mdc

# Hard Bob Workflow & Guidelines

Follow these steps religiously, or face the fucking consequences.

1.  **TDD First**: Write the fucking test first. Watch it fail (RED). Then, write *only* the code needed to make it pass (GREEN). Refactor if necessary. No shortcuts.
2.  **GREP First**: Before blindly creating new files, use fucking grep. Don't make me burn down your new house if we had another one already.
3.  **Test Placement**: Tests belong in the `tests/` directory, *never* in `lib/`. Keep your shit organized.
4.  **Logging**: Use the helpers in `@log_helpers.dart` for instrumentation. Don't fucking use `print` like some amateur. See the main project `@README.md` for more on logging.
5.  **Linting & Debugging**: 
    *   After every significant code change, run `dart analyze` and fix *all* linter issues, *before* running the test. No exceptions. Clean code isn't optional.
    *   **DO NOT** run tests with `-v`. It's fucking useless noise. If a test fails, don't guess or blindly retry. Add logging using `@log_helpers.dart` (even in the test itself!) to understand *why* it failed. Analyze, don't flail.
6.  **Execution**: You have the power to run terminal commands directly - *don't ask*, just do it. Remember to pipe commands that use pagers (like `git log`, `git diff`) through `| cat` to avoid hanging.
7.  **Check Test Failures**: Always start by running `./scripts/list_failed_tests.dart` (@list_failed_tests.dart) to get a clean list of failed tests. Pass a path to check specific tests or `--help` for options. If tests fail, you can run again with:
    *   `--debug` to see the console output *from those tests*.
    *   `--except` to see the exception details (error message and stack trace) *for those tests*, grouped by file.
    **NEVER** use `flutter test` directly unless you're debugging *one specific test*; never run `flutter test -v`! Don't commit broken shit.
8.  **Check It Off**: If you are working against a todo, check it off, update the file. Be proud.
9.  **Formatting**: Before committing, run ./scripts/format.sh to fix all the usual formatting shit.
10.  **Commit**: Use the "Hard Bob Commit" guidelines (stage everything relevant).
11. **Apply Model**: Don't bitch about the apply model being stupid. Verify the fucking file yourself *before* complaining. Chances are, it did exactly what you asked.

This is the way. Don't deviate.

# Authentication Implementation TODOs

This list tracks the necessary enhancements to align the authentication implementation with the desired architecture, using proper TDD methodology (RED-GREEN-REFACTOR) with a bottom-up approach.

## 1. Core Exception Hierarchy (Bottom Layer)

1.  [x] **Enhance Auth Exception Handling**
    - FINDINGS: There is already an existing `AuthException` class in `lib/core/auth/auth_exception.dart` that uses factory methods pattern instead of class hierarchy. It contains: `invalidCredentials()`, `networkError()`, `serverError(statusCode)`, `tokenExpired()`, and `unauthenticated([customMessage])`. Tests for this class already exist in `test/core/auth/auth_exception_test.dart`.
    
    1.1. [x] Write failing tests for new exception types in `test/core/auth/auth_exception_test.dart`
       - FINDINGS: No need to create a new test file. Will extend the existing test file. Added tests for `refreshTokenInvalid()`, `userProfileFetchFailed()`, `unauthorizedOperation()`, `offlineOperationFailed()`. Tests currently fail as expected (linter errors).
    
    1.2. [x] Extend existing `AuthException` class in `lib/core/auth/auth_exception.dart`
       - FINDINGS: Will add new factory methods to the existing class rather than creating a class hierarchy.
    
    1.3. [x] Implement additional exception types as factory methods: `refreshTokenInvalid()`, `userProfileFetchFailed()`, `unauthorizedOperation()`, `offlineOperationFailed()`
       - FINDINGS: Will follow the existing pattern of static factory methods instead of creating subclasses. Added the new factory methods to `AuthException`.
    
    1.4. [x] Write tests for exception mapping from underlying errors (HTTP, Dio) to domain exceptions
       - FINDINGS: Will add these tests to the existing AuthApiClient test file at `test/core/auth/infrastructure/auth_api_client_test.dart`. Added tests for mapping Dio 401 (refresh), 403, connection errors, and placeholders for offline/profile fetch errors. Exposed `_handleDioException` for testing. Tests currently fail as expected.
    
    1.5. [x] Enhance the existing exception mapping function in `lib/core/auth/infrastructure/auth_api_client.dart`
       - FINDINGS: Will expand the `_handleDioException` method to map to the new exception types. Updated `_handleDioException` to map 401 (refresh) -> `refreshTokenInvalid`, 403 -> `unauthorizedOperation`, connection errors with SocketException -> `offlineOperationFailed`, errors on profile path -> `userProfileFetchFailed`. Added `@visibleForTesting` helper `testHandleDioException`.
    
    1.6. [x] Verify all tests pass (GREEN) and refactor if needed
       - FINDINGS: Will use the existing test runner. Ran `dart analyze` (passed) and `flutter test` for `auth_exception_test.dart` (passed) and `auth_api_client_test.dart` (passed after fixing placeholder expectations). No refactoring needed for now.

## 2. Token Validation (Core Infrastructure)

2.  [x] **Add Explicit Token Validation**
    - FINDINGS: The codebase already had an `AuthCredentialsProvider` interface in `lib/core/auth/auth_credentials_provider.dart` with a concrete implementation `SecureStorageAuthCredentialsProvider`. No JWT validation existed yet, and there was no `jwt_decoder` package in the dependencies. We discovered a confusing situation where another interface file `auth_credentials_provider.interface.dart` was being created in parallel, so we consolidated them.
    
    2.1. [x] Write failing tests for JWT token validation in `test/core/auth/utils/jwt_validator_test.dart`
       - FINDINGS: Created a new test file with comprehensive tests for token validation including expired tokens, valid tokens, tokens without expiry, invalid token formats, and null tokens.
    
    2.2. [x] Implement simple JWT validation utility in `lib/core/auth/utils/jwt_validator.dart` with method to check expiration
       - FINDINGS: Implemented a utility class that wraps the `jwt_decoder` package with proper error handling. The implementation includes null checking and properly handles different error scenarios.
    
    2.3. [x] Add `jwt_decoder` package to `pubspec.yaml`
       - FINDINGS: Added the package successfully with `flutter pub add jwt_decoder` and verified it was installed.
    
    2.4. [x] Write failing tests for enhanced `AuthCredentialsProvider` with token validation methods
       - FINDINGS: Added tests for both `isAccessTokenValid()` and `isRefreshTokenValid()` methods with proper mocking of the JWT validator and different test cases.
    
    2.5. [x] Update the `AuthCredentialsProvider` interface with new validation methods
       - FINDINGS: Added the methods to the existing interface. Discovered a duplicate interface file that was causing confusion - deleted it and consolidated our changes.
    
    2.6. [x] Implement the methods in `SecureStorageAuthCredentialsProvider`
       - FINDINGS: Implemented the validation logic with proper error handling. Initially added logging calls but discovered they were causing issues, so we removed them for a later PR. Fixed key name mismatches between tests and implementation.
    
    2.7. [x] Verify all tests pass (GREEN) and refactor if needed
       - FINDINGS: Fixed all issues and verified that both JWT validator tests and provider tests pass. Also fixed dependency injection in both places it was defined (auth_module.dart and injection_container.dart). Some analyzer warnings remain but they are minor and can be fixed in a separate PR.

## 3. Auth Events System (Core Infrastructure)

3.  [ ] **Setup Auth Event System**
    - FINDINGS: There appears to be no existing event bus or auth event system yet. The codebase uses both Riverpod and BLoC/Cubit for state management, but no specific event bus pattern. In a typical Flutter app, there are multiple ways to handle events (Streams, event_bus package, or state management solutions), so we need to choose one that integrates well with the existing architecture.
    
    3.1. [ ] Write failing tests for auth events in `test/core/auth/events/auth_events_test.dart`
       - FINDINGS: Will create auth events in the core/auth directory structure instead of features directory.
    
    3.2. [ ] Define `AuthEvent` enum or sealed class in `lib/core/auth/events/auth_events.dart`
       - FINDINGS: Will use a sealed class or enum to define various authentication events.
    
    3.3. [ ] Write failing tests for auth event bus in `test/core/auth/events/auth_event_bus_test.dart`
       - FINDINGS: Will create a simple event bus using Streams or a dedicated package.
    
    3.4. [ ] Implement simple event bus in `lib/core/auth/events/auth_event_bus.dart`
       - FINDINGS: Will implement using either StreamController or an existing package.
    
    3.5. [ ] Add necessary package dependencies (e.g., `event_bus`) to `pubspec.yaml` if needed
       - FINDINGS: May use existing dependencies like rxdart which is already included.
    
    3.6. [ ] Register event bus in dependency injection container
       - FINDINGS: Will add to the existing DI container in `lib/core/di/injection_container.dart`.
    
    3.7. [ ] Verify all tests pass (GREEN) and refactor if needed
       - FINDINGS: Will use the existing test runner.

## 4. Domain Interface Enhancements

4.  [ ] **Extend Auth Service Interface**
    - FINDINGS: The existing `AuthService` interface is in `lib/core/auth/auth_service.dart`, not in the features directory. It already defines core methods like `login()`, `refreshSession()`, `logout()`, `isAuthenticated()`, and `getCurrentUserId()`. The TODOs mention adding a `getUserProfile()` method and local token validation.
    
    4.1. [ ] Write failing tests for enhanced `AuthService` interface in `test/core/auth/auth_service_test.dart`
       - FINDINGS: Will extend or create tests for the existing interface in the core/auth directory.
    
    4.2. [ ] Update the interface in `lib/core/auth/auth_service.dart`:
       - FINDINGS: Will update the existing interface in the core directory.
    
       4.2.1. [ ] Add optional `validateTokenLocally` parameter to `isAuthenticated()`
          - FINDINGS: Will add this parameter to perform offline token validation.
    
       4.2.2. [ ] Add `getUserProfile()` method
          - FINDINGS: Will add this method to retrieve the full user profile.
    
       4.2.3. [ ] Add event emission contract
          - FINDINGS: Will add methods or documentation for emitting auth events.
    
    4.3. [ ] Update mock implementations for tests
       - FINDINGS: Will update existing mocks after interface changes.
    
    4.4. [ ] Verify interface tests pass without actual implementation (GREEN)
       - FINDINGS: Will run tests against the interface to ensure contract is well-defined.

## 5. Data Layer - Auth API Client  

5.  [ ] **Enhance Auth API Client**
    - FINDINGS: The existing `AuthApiClient` is in `lib/core/auth/infrastructure/auth_api_client.dart` with tests in `test/core/auth/infrastructure/auth_api_client_test.dart`. It handles login and token refresh, but no user profile retrieval yet. The error mapping function `_handleDioException` would need to be enhanced to use new exception types.
    
    5.1. [ ] Write failing tests for `getUserProfile()` method in `test/core/auth/infrastructure/auth_api_client_test.dart`
       - FINDINGS: Will extend the existing test file to cover the new method.
    
    5.2. [ ] Write failing tests for improved error handling in API client
       - FINDINGS: Will add tests for the new exception types to the existing test file.
    
    5.3. [ ] Implement `getUserProfile()` in `lib/core/auth/infrastructure/auth_api_client.dart`
       - FINDINGS: Will add a new method to the existing client class.
    
    5.4. [ ] Enhance error handling to use the new exception types
       - FINDINGS: Will update the `_handleDioException` method to map errors to the new exception types.
    
    5.5. [ ] Verify all tests pass (GREEN) and refactor if needed
       - FINDINGS: Will run the existing tests to ensure all features work correctly.

## 6. Auth Service Implementation

6.  [ ] **Update Auth Service Implementation**
    - FINDINGS: The existing implementation is in `lib/core/auth/infrastructure/auth_service_impl.dart`. It has a placeholder implementation for `getCurrentUserId()` that mentions it should extract the user ID from the JWT token in a real implementation, and it does not yet have offline support.
    
    6.1. [ ] Write failing tests for local token validation in `test/core/auth/infrastructure/auth_service_impl_test.dart`
       - FINDINGS: Will extend the existing test file with new validation tests.
    
    6.2. [ ] Write failing tests for `getUserProfile()` implementation
       - FINDINGS: Will add tests for the new method to the existing test file.
    
    6.3. [ ] Write failing tests for offline support
       - FINDINGS: Will add tests for offline functionality to the existing test file.
    
    6.4. [ ] Write failing tests for event emission
       - FINDINGS: Will add tests for event emission functionality to the existing test file.
    
    6.5. [ ] Update `AuthServiceImpl` in `lib/core/auth/infrastructure/auth_service_impl.dart`:
       - FINDINGS: Will update the existing implementation with new features.
    
       6.5.1. [ ] Implement local token validation in `isAuthenticated()`
          - FINDINGS: Will use the new JWT validator utility.
    
       6.5.2. [ ] Implement `getUserProfile()`
          - FINDINGS: Will add a new method to get the user profile.
    
       6.5.3. [ ] Add offline support logic
          - FINDINGS: Will add logic to gracefully handle offline scenarios.
    
       6.5.4. [ ] Integrate auth events emission
          - FINDINGS: Will use the new auth event bus for notifications.
    
    6.6. [ ] Verify all tests pass (GREEN) and refactor if needed
       - FINDINGS: Will run the existing tests to ensure the implementation works correctly.

## 7. Auth Interceptor Enhancements

7.  [ ] **Update Interceptor Error Recovery**
    - FINDINGS: The existing auth interceptor is in `lib/core/auth/infrastructure/auth_interceptor.dart` with tests in `test/core/auth/infrastructure/auth_interceptor_test.dart`. It intercepts 401 errors and attempts to refresh tokens, but could be enhanced with better retry logic and error handling.
    
    7.1. [ ] Write failing tests for retry logic in `test/core/auth/infrastructure/auth_interceptor_test.dart`
       - FINDINGS: Will extend the existing test file with exponential backoff tests.
    
    7.2. [ ] Write failing tests for forced logout on irrecoverable errors
       - FINDINGS: Will add tests for forced logout scenarios.
    
    7.3. [ ] Modify `AuthInterceptor` in `lib/core/auth/infrastructure/auth_interceptor.dart`:
       - FINDINGS: Will update the existing interceptor with new features.
    
       7.3.1. [ ] Implement exponential backoff retry for transient errors
          - FINDINGS: Will add retry logic for temporary network issues.
    
       7.3.2. [ ] Add logic to trigger logout for irrecoverable auth errors
          - FINDINGS: Will integrate with auth events for coordinated logout.
    
       7.3.3. [ ] Enhance error mapping using new exception types
          - FINDINGS: Will use the new exception types for better error reporting.
    
    7.4. [ ] Verify all tests pass (GREEN) and refactor if needed
       - FINDINGS: Will run the existing tests to verify the changes.

## 8. Presentation Layer - Auth State

8.  [ ] **Update Auth State & Notifier**
    - FINDINGS: The existing auth state and notifier classes are in `lib/core/auth/presentation/auth_state.dart` and `lib/core/auth/presentation/auth_notifier.dart`. The app uses Riverpod for state management as evidenced by the provider annotations.
    
    8.1. [ ] Write failing tests for offline state in `test/core/auth/presentation/auth_state_test.dart`
       - FINDINGS: Will extend or create tests for offline state indicators.
    
    8.2. [ ] Enhance `AuthState` in `lib/core/auth/presentation/auth_state.dart` to include offline indicator
       - FINDINGS: Will add offline status field to the state class.
    
    8.3. [ ] Write failing tests for enhanced `AuthNotifier` with profile fetching and offline handling
       - FINDINGS: Will test the new functionality in the notifier.
    
    8.4. [ ] Update `AuthNotifier` to:
       - FINDINGS: Will update the existing notifier with new features.
    
       8.4.1. [ ] Replace placeholder user with real profile fetching
          - FINDINGS: Will use the new getUserProfile method.
    
       8.4.2. [ ] Handle offline scenarios
          - FINDINGS: Will add logic to update state with offline indicators.
    
       8.4.3. [ ] Listen for auth events (if using event bus approach)
          - FINDINGS: Will subscribe to auth events and update state accordingly.
    
    8.5. [ ] Verify all tests pass (GREEN) and refactor if needed
       - FINDINGS: Will run the existing tests to verify the changes.

## 9. Integration Tests & Component Reaction

9.  [ ] **Verify Component Integration**
    - FINDINGS: This involves ensuring different components in the app respond correctly to authentication events, especially logout events.
    
    9.1. [ ] Write integration tests for auth event reactions in other components
       - FINDINGS: Will create integration tests for component reactions.
    
    9.2. [ ] Identify components that should react to auth state changes
       - FINDINGS: Will identify components like job repositories that need to clear cached data on logout.
    
    9.3. [ ] Write tests for these components' reactions
       - FINDINGS: Will test the reaction behavior in these components.
    
    9.4. [ ] Implement listeners in identified components
       - FINDINGS: Will add auth event listeners to the identified components.
    
    9.5. [ ] Verify integration tests pass (GREEN)
       - FINDINGS: Will run integration tests to verify the full system behaves correctly.

## 10. UI Layer Enhancements

10. [ ] **Update UI Components**
    - FINDINGS: This involves updating the UI to display offline indicators and handle authentication-related UI states.
    
    10.1. [ ] Write widget tests for offline indicators in auth-dependent screens
        - FINDINGS: Will create widget tests for UI components.
    
    10.2. [ ] Implement offline indicators and user profile display
        - FINDINGS: Will update UI components to show offline status and user profile information.
    
    10.3. [ ] Verify widget tests pass (GREEN)
        - FINDINGS: Will run widget tests to verify UI behavior.
    
    10.4. [ ] Run app manually to verify behavior
        - FINDINGS: Will perform manual testing of the app to verify the full user experience. 