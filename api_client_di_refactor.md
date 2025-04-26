# TDD Approach: API Client DI Refactoring Plan

## Issue

The current architecture incorrectly routes authenticated requests through `basicDio` instead of `authenticatedDio`:

- `AuthApiClient` is registered with `basicDio` as its only HTTP client
- `getUserProfile()` and other authenticated endpoints require JWT tokens 
- The current setup produces "Missing API key" errors when it should produce "401 Unauthorized" errors
- Tests are failing because they expect correct authentication behavior

This violates the intended design where `authenticatedDio` should handle all requests requiring JWT tokens.

## Goal

Refactor the API client architecture to properly separate authenticated and non-authenticated request contexts, ensuring:

1. Proper token injection for authenticated endpoints
2. Clear separation of responsibilities
3. No circular dependencies in DI graph
4. Test stability and correctness
5. Minimal disturbance to the rest of the codebase

## Approach: Test-Driven Split Client Architecture

We'll implement the "Split Client" pattern using Test-Driven Development (TDD):
- `AuthenticationApiClient` - Handles login/refresh with `basicDio`
- `UserApiClient` - Handles user profile with `authenticatedDio`

Each change will follow the RED-GREEN-REFACTOR cycle:
1. Write/modify a failing test (RED)
2. Make minimal changes to pass the test (GREEN)
3. Refactor for clean code while keeping tests passing

## TDD Implementation Cycles

### Cycle 1: Verify Failing State and Create Test for AuthenticationApiClient

#### 1.1 RED: Verify Current Tests Fail
- [x] Run `./scripts/list_failed_tests.dart test/core/auth/infrastructure/auth_module_test.dart --debug`
- [x] Confirm the exact failure mode in "getUserProfile needs JWT token" test
- [x] Document the failure for comparison after changes

**Insights:**
- The tests confirmed our diagnosis: getUserProfile is failing with "Missing API key" instead of a 401 auth error.
- The root issue is in the DI setup where AuthApiClient is constructed with basicDio instead of authenticatedDio.
- We can see in the test logs that the tests explicitly expect (and verify) this to be fixed by properly injecting authenticatedDio.

#### 1.2 RED: Create AuthenticationApiClient Test
- [x] Create `test/core/auth/infrastructure/authentication_api_client_test.dart`
- [x] Write tests for login and refreshToken that expect BasicDio
- [x] Run the tests to confirm they fail (RED)

**Insights:**
- Created tests that explicitly verify the new AuthenticationApiClient uses basicDio for login/refresh operations.
- Improved test structure with clear Arrange-Act-Assert pattern and better test isolation.
- We've added specific error cases to ensure the new client handles errors properly.

#### 1.3 GREEN: Create AuthenticationApiClient
- [x] Create `lib/core/auth/infrastructure/authentication_api_client.dart`
- [x] Implement login and refreshToken methods copied from AuthApiClient
- [x] Make minimal changes to pass the tests
- [x] Run tests to verify they pass (GREEN)

**Insights:**
- Successfully implemented AuthenticationApiClient with clear responsibility for non-authenticated endpoints.
- Used parameter name `basicHttpClient` to make it explicit that this client requires the non-authenticated Dio instance.
- Improved documentation to clarify the purpose of this client in the architecture.
- Tests are now passing, confirming our implementation works as expected.

#### 1.4 REFACTOR: Clean Up New Client
- [x] Add proper documentation
- [x] Improve error handling if needed
- [x] Ensure tests still pass after refactoring

**Insights:**
- Enhanced documentation clarifies that this client handles pre-authentication operations.
- Simplified error handling by removing profile-specific code since this client never handles profile requests.
- Maintained clear parameter naming (`basicHttpClient`) to prevent future confusion.
- Tests continue to pass after refactoring.

**Guidance for the next developer (Cycle 2):**
1. Create the full directory structure for `UserApiClient` first:
   ```
   lib/core/user/
   lib/core/user/infrastructure/
   test/core/user/infrastructure/
   ```

2. Create a proper user profile DTO to replace the current TODO in `AuthApiClient.getUserProfile()`:
   ```dart
   // Create this first:
   lib/core/user/infrastructure/dtos/user_profile_dto.dart
   ```

3. When implementing `UserApiClient`, use explicit naming for the Dio parameter:
   ```dart
   UserApiClient({
     required this.authenticatedHttpClient,  // Note the explicit name
     required this.credentialsProvider,
   });
   ```

4. In tests, explicitly verify that `authenticatedDio` is used and `basicDio` is never used for profile requests.

5. Remember that the `AuthInterceptor` function reference will need updating later to point to the new `AuthenticationApiClient` - don't worry about this yet, but keep it in mind.

6. The most challenging part will be in Cycle 3 when updating the DI registration in `AuthModule` - study the current registration order carefully before making changes.

### Cycle 2: Create UserApiClient

#### 2.1 RED: Create UserApiClient Test
- [x] Create `test/core/user/infrastructure/user_api_client_test.dart`
- [x] Write test for getUserProfile that explicitly expects AuthenticatedDio
- [x] Run the test to confirm it fails (RED)

**Insights:**
- Created a test suite that explicitly verifies UserApiClient uses authenticatedDio for profile requests.
- Implemented three test cases: successful profile retrieval, error handling, and 401 authentication failures.
- Used the Mocktail framework for mocking Dio and AuthCredentialsProvider dependencies.
- The test structure follows the Arrange-Act-Assert pattern for clarity.
- The failing test helped identify the requirements for the actual implementation.

#### 2.2 GREEN: Create UserApiClient
- [x] Create necessary directories and `lib/core/user/infrastructure/user_api_client.dart`
- [x] Implement getUserProfile method migrated from AuthApiClient
- [x] Make the implementation pass the test
- [x] Run test to verify it passes (GREEN)

**Insights:**
- Created a clean UserProfileDto class to handle API response data (with JSON serialization).
- Designed UserApiClient with clear constructor parameter names (`authenticatedHttpClient`) to prevent confusion.
- Successfully implemented getUserProfile to use the authenticatedDio instance.
- Maintained proper error handling that preserves context about failures.
- The implementation passes all test cases, verifying the correct usage of authenticatedDio.

#### 2.3 REFACTOR: Clean Up User Client
- [x] Add proper documentation
- [x] Enhance error handling
- [x] Verify tests still pass

**Insights:**
- Enhanced documentation to clearly explain the Split Client pattern and responsibilities.
- Added explicit warnings about using authenticatedDio vs basicDio to prevent future errors.
- Improved error handling with more specific context for different error types (network, auth, unexpected).
- Added comprehensive JSDoc-style annotations for better IDE support and developer guidance.
- Tests continue to pass after refactoring, confirming the implementation is solid.

**Guidance for the next developer (Cycle 3):**
1. When updating the AuthModule registration in Cycle 3, ensure UserApiClient explicitly receives authenticatedDio.
2. The key pattern to follow is:
   ```dart
   // Register AuthenticationApiClient with basicDio
   getIt.registerFactory<AuthenticationApiClient>(() => AuthenticationApiClient(
     basicHttpClient: sl<Dio>('basicDio'),
     credentialsProvider: credentialsProvider,
   ));
   
   // Register UserApiClient with authenticatedDio
   getIt.registerFactory<UserApiClient>(() => UserApiClient(
     authenticatedHttpClient: sl<Dio>('authenticatedDio'),
     credentialsProvider: credentialsProvider,
   ));
   ```

3. When updating tests, be sure to verify that DI registration correctly passes the different Dio instances.

4. Remember that the most important part of this refactoring is ensuring UserApiClient receives authenticatedDio to fix the "Missing API key" errors.

5. For the AuthModule test, explicitly verify that:
   - AuthenticationApiClient gets basicDio for unauthenticated operations
   - UserApiClient gets authenticatedDio for authenticated operations

### Cycle 3: Update AuthModule Registration Test

#### 3.1 RED: Modify AuthModule Test
- [ ] Update `auth_module_test.dart` to verify both clients are registered correctly
- [ ] Create test case that verifies AuthenticationApiClient gets basicDio
- [ ] Create test case that verifies UserApiClient gets authenticatedDio
- [ ] Run tests to confirm they fail (RED)

#### 3.2 GREEN: Update AuthModule Registration
- [ ] Modify `auth_module.dart` to register both clients properly
- [ ] Ensure circular dependencies are broken properly with function-based DI
- [ ] Run tests to verify they pass (GREEN)

#### 3.3 REFACTOR: Clean Up Module
- [ ] Improve registration order and documentation
- [ ] Remove any redundant code
- [ ] Ensure tests still pass

### Cycle 4: Update AuthService Interface and Implementation

#### 4.1 RED: Update AuthService Tests
- [ ] Modify AuthService tests to reflect the updated dependency structure
- [ ] Set expectations for both clients being used for their respective methods
- [ ] Run tests to confirm they fail (RED)

#### 4.2 GREEN: Update AuthServiceImpl
- [ ] Modify AuthServiceImpl to inject both new clients
- [ ] Update method implementations to call the correct client
- [ ] Run tests to verify they pass (GREEN)

#### 4.3 REFACTOR: Clean Up Service Implementation
- [ ] Improve error handling
- [ ] Add documentation
- [ ] Verify tests still pass

### Cycle 5: Handle Smooth Transition (Legacy Support)

#### 5.1 RED: Create Legacy Compatibility Tests
- [ ] Create tests that verify the old AuthApiClient still works if used
- [ ] Test that it forwards calls to the correct new client
- [ ] Run tests to confirm they fail (RED)

#### 5.2 GREEN: Implement Legacy Compatibility
- [ ] Mark AuthApiClient as @deprecated with migration notes
- [ ] Modify it to delegate to the appropriate new client
- [ ] Run tests to verify they pass (GREEN)

#### 5.3 REFACTOR: Plan for Eventual Removal
- [ ] Add logging to track usage of deprecated methods
- [ ] Document timeline for removal
- [ ] Ensure all tests still pass

### Cycle 6: Fix Original Failing Test

#### 6.1 RED: Review Original Test Failure
- [ ] Re-examine the original "getUserProfile needs JWT token" test
- [ ] Confirm it's still failing with the current implementation

#### 6.2 GREEN: Complete Integration
- [ ] Make any final adjustments to fix the failing test
- [ ] Ensure AuthInterceptor now gets its refreshToken function from AuthenticationApiClient
- [ ] Run tests to verify they pass (GREEN)

#### 6.3 REFACTOR: Clean Up and Integrate
- [ ] Improve error messages
- [ ] Add clear logging
- [ ] Run full test suite to ensure everything passes

### Cycle 7: Verify No Regressions

#### 7.1 RED: Create Additional Verification Tests
- [ ] Create combined tests that verify complete auth flow (login → get profile)
- [ ] Add tests for error handling between components
- [ ] Run the tests to identify any issues (RED if issues exist)

#### 7.2 GREEN: Fix Any Regressions
- [ ] Fix any regressions or integration issues
- [ ] Run tests to verify everything passes (GREEN)

#### 7.3 REFACTOR: Final Documentation and Guidelines
- [ ] Document the new pattern for future API clients
- [ ] Create guidelines for which Dio to use when
- [ ] Update architecture documentation

## Post-Implementation Verification

- [ ] Run all tests (`dart test` or `./scripts/list_failed_tests.dart`)
- [ ] Manually test the app login and profile flow
- [ ] Review logs to ensure proper authentication behavior
- [ ] Verify no new warnings or errors are introduced

## Additional Insights

### Root Cause Analysis

- The symptom (API key errors instead of 401s) occurs because requests never reach the auth interceptor - they're failing earlier at the API key step. This makes debugging confusing and error messages misleading.
- Looking at the logs, what appears to be an authentication failure is actually a different type of error entirely.

### Feature-Wide Implications

- This issue will affect EVERY authenticated endpoint (Jobs, Documents, etc.). When implementing those features, use the new pattern from day one to avoid repeating the mistake.
- The Job dataflow architecture documents (feature-job-dataflow.md) should be updated to reflect the correct client pattern.

### Testing Enhancements

- Add explicit tests that verify `authenticatedDio` includes both the API key AND JWT token
- Test the specific error cases to ensure we get the right error types (401 vs API key error)
- Add integration tests that validate the entire request pipeline with mock servers

### Implementation Guidelines

- Create a pattern document for new API clients with clear examples of which Dio instance to use
- Consider adding compile-time annotations like `@RequiresAuth` or `@PublicEndpoint` to make requirements explicit
- Make constructor signatures different enough that you can't accidentally inject the wrong Dio:
  ```dart
  // Instead of both taking generic "httpClient"
  AuthenticationApiClient({required Dio basicHttpClient})
  UserApiClient({required Dio authenticatedHttpClient})
  ```

### Future-Proofing

- Consider adding runtime assertions in debug mode that verify endpoints requiring auth are being called with `authenticatedDio`
- Document this pattern clearly in onboarding materials for new devs

This fix addresses a fundamental architectural pattern - getting it right will pay dividends across the entire codebase. 