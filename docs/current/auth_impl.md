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

1.  [ ] **Enhance Auth Exception Handling**
    1.1. [ ] Write failing tests for new exception class hierarchy in `test/features/auth/domain/errors/auth_exceptions_test.dart`
    1.2. [ ] Create or extend base `AuthException` class in `lib/features/auth/domain/errors/auth_exceptions.dart`
    1.3. [ ] Implement specific exception subtypes: `InvalidCredentialsException`, `TokenExpiredException`, `RefreshTokenInvalidException`, `NetworkException`, `UserProfileFetchException`, etc.
    1.4. [ ] Write tests for exception mapping from underlying errors (HTTP, Dio) to domain exceptions
    1.5. [ ] Implement the exception mapping functions/utilities
    1.6. [ ] Verify all tests pass (GREEN) and refactor if needed

## 2. Token Validation (Core Infrastructure)

2.  [ ] **Add Explicit Token Validation**
    2.1. [ ] Write failing tests for JWT token validation in `test/features/auth/data/utils/jwt_validator_test.dart`
    2.2. [ ] Implement simple JWT validation utility in `lib/features/auth/data/utils/jwt_validator.dart` with method to check expiration
    2.3. [ ] Add `jwt_decoder` package to `pubspec.yaml`
    2.4. [ ] Write failing tests for enhanced `AuthCredentialsProvider` with token validation methods
    2.5. [ ] Update the `AuthCredentialsProvider` interface with new validation methods
    2.6. [ ] Implement the methods in `SecureStorageAuthCredentialsProvider`
    2.7. [ ] Verify all tests pass (GREEN) and refactor if needed

## 3. Auth Events System (Core Infrastructure)

3.  [ ] **Setup Auth Event System**
    3.1. [ ] Write failing tests for auth events in `test/features/auth/domain/events/auth_events_test.dart`
    3.2. [ ] Define `AuthEvent` enum or sealed class in `lib/features/auth/domain/events/auth_events.dart`
    3.3. [ ] Write failing tests for auth event bus in `test/features/auth/domain/events/auth_event_bus_test.dart`
    3.4. [ ] Implement simple event bus in `lib/features/auth/domain/events/auth_event_bus.dart`
    3.5. [ ] Add necessary package dependencies (e.g., `event_bus`) to `pubspec.yaml` if needed
    3.6. [ ] Register event bus in dependency injection container
    3.7. [ ] Verify all tests pass (GREEN) and refactor if needed

## 4. Domain Interface Enhancements

4.  [ ] **Extend Auth Service Interface**
    4.1. [ ] Write failing tests for enhanced `AuthService` interface in `test/features/auth/domain/repositories/auth_service_test.dart`
    4.2. [ ] Update the interface in `lib/features/auth/domain/repositories/auth_service.dart`:
        4.2.1. [ ] Add optional `validateTokenLocally` parameter to `isAuthenticated()`
        4.2.2. [ ] Add `getUserProfile()` method
        4.2.3. [ ] Add event emission contract
    4.3. [ ] Update mock implementations for tests
    4.4. [ ] Verify interface tests pass without actual implementation (GREEN)

## 5. Data Layer - Auth API Client  

5.  [ ] **Enhance Auth API Client**
    5.1. [ ] Write failing tests for `getUserProfile()` method in `test/features/auth/data/sources/auth_api_client_test.dart`
    5.2. [ ] Write failing tests for improved error handling in API client
    5.3. [ ] Implement `getUserProfile()` in `lib/features/auth/data/sources/auth_api_client.dart`
    5.4. [ ] Enhance error handling to use the new exception types
    5.5. [ ] Verify all tests pass (GREEN) and refactor if needed

## 6. Auth Service Implementation

6.  [ ] **Update Auth Service Implementation**
    6.1. [ ] Write failing tests for local token validation in `test/features/auth/data/repositories/auth_service_impl_test.dart`
    6.2. [ ] Write failing tests for `getUserProfile()` implementation
    6.3. [ ] Write failing tests for offline support
    6.4. [ ] Write failing tests for event emission
    6.5. [ ] Update `AuthServiceImpl` in `lib/features/auth/data/repositories/auth_service_impl.dart`:
        6.5.1. [ ] Implement local token validation in `isAuthenticated()`
        6.5.2. [ ] Implement `getUserProfile()`
        6.5.3. [ ] Add offline support logic
        6.5.4. [ ] Integrate auth events emission
    6.6. [ ] Verify all tests pass (GREEN) and refactor if needed

## 7. Auth Interceptor Enhancements

7.  [ ] **Update Interceptor Error Recovery**
    7.1. [ ] Write failing tests for retry logic in `test/core/network/interceptors/auth_interceptor_test.dart`
    7.2. [ ] Write failing tests for forced logout on irrecoverable errors
    7.3. [ ] Modify `AuthInterceptor` in `lib/core/network/interceptors/auth_interceptor.dart`:
        7.3.1. [ ] Implement exponential backoff retry for transient errors
        7.3.2. [ ] Add logic to trigger logout for irrecoverable auth errors
        7.3.3. [ ] Enhance error mapping using new exception types
    7.4. [ ] Verify all tests pass (GREEN) and refactor if needed

## 8. Presentation Layer - Auth State

8.  [ ] **Update Auth State & Notifier**
    8.1. [ ] Write failing tests for offline state in `test/features/auth/presentation/state/auth_state_test.dart`
    8.2. [ ] Enhance `AuthState` in `lib/features/auth/presentation/state/auth_state.dart` to include offline indicator
    8.3. [ ] Write failing tests for enhanced `AuthNotifier` with profile fetching and offline handling
    8.4. [ ] Update `AuthNotifier` to:
        8.4.1. [ ] Replace placeholder user with real profile fetching
        8.4.2. [ ] Handle offline scenarios
        8.4.3. [ ] Listen for auth events (if using event bus approach)
    8.5. [ ] Verify all tests pass (GREEN) and refactor if needed

## 9. Integration Tests & Component Reaction

9.  [ ] **Verify Component Integration**
    9.1. [ ] Write integration tests for auth event reactions in other components
    9.2. [ ] Identify components that should react to auth state changes
    9.3. [ ] Write tests for these components' reactions
    9.4. [ ] Implement listeners in identified components
    9.5. [ ] Verify integration tests pass (GREEN)

## 10. UI Layer Enhancements

10. [ ] **Update UI Components**
    10.1. [ ] Write widget tests for offline indicators in auth-dependent screens
    10.2. [ ] Implement offline indicators and user profile display
    10.3. [ ] Verify widget tests pass (GREEN)
    10.4. [ ] Run app manually to verify behavior 