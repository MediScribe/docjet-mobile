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

6. **Complete Legacy AuthApiClient Implementation**: The current implementation of the legacy AuthApiClient for backward compatibility still uses basicDio directly. For full correctness, it should delegate to the appropriate specialized client based on the method called:
   ```dart
   // In AuthApiClient
   Future<UserProfileDto> getUserProfile() {
     // Delegate to UserApiClient for profile endpoints
     return getIt<UserApiClient>().getUserProfile();
   }
   
   Future<AuthResponseDto> login(String email, String password) {
     // Delegate to AuthenticationApiClient for auth endpoints
     return getIt<AuthenticationApiClient>().login(email, password);
   }
   ```

7. **Auth Interceptor Uses Function Reference**: Note that AuthInterceptor takes a function reference, not a direct dependency on AuthenticationApiClient. The critical line is:
   ```dart
   refreshTokenFunction: (refreshToken) => authApiClient.refreshToken(refreshToken)
   ```
   This allows us to break the circular dependency. When updating other files, maintain this pattern.

8. **Test File Fixing Approach**: When fixing the failing integration tests, update the mocks first, then the test expectations. The signature changes from AuthApiClient to AuthenticationApiClient will require careful updates to all mock creation and verification code.

9. **Core Responsibility Division**: 
   - AuthenticationApiClient: login, refreshToken (uses basicDio)
   - UserApiClient: getUserProfile, other user operations (uses authenticatedDio)

10. **Tests Must Verify Proper Client Usage**: Each test should explicitly verify the right requests go through the right Dio instance - that's the whole point of the refactoring.

11. **Fix These Pending Analyzer Issues**: After Cycle 3, we still have these remaining issues to address:
    ```
    error • test/core/auth/infrastructure/auth_module_integration_test.dart:183:28 • The argument type
            'AuthApiClient' can't be assigned to the parameter type 'AuthenticationApiClient'.
    error • test/core/auth/infrastructure/dio_factory_test.dart:196:28 • The argument type
            'MockAuthApiClient' can't be assigned to the parameter type 'AuthenticationApiClient'.
    error • test/core/auth/infrastructure/dio_factory_test.dart:255:28 • The argument type
            'MockAuthApiClient' can't be assigned to the parameter type 'AuthenticationApiClient'.
    error • test/core/auth/infrastructure/dio_factory_test.dart:301:26 • The argument type
            'MockAuthApiClient' can't be assigned to the parameter type 'AuthenticationApiClient'.
    error • test/core/auth/infrastructure/dio_factory_test.dart:369:24 • The argument type
            'MockAuthApiClient' can't be assigned to the parameter type 'AuthenticationApiClient'.
    error • test/core/auth/infrastructure/dio_factory_test.dart:418:26 • The argument type
            'MockAuthApiClient' can't be assigned to the parameter type 'AuthenticationApiClient'.
    warning • lib/core/auth/infrastructure/dio_factory.dart:5:8 • Unused import:
            'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart'.
    warning • lib/core/user/infrastructure/user_api_client.dart:5:8 • Unused import:
            'package:flutter/foundation.dart'.
    warning • test/core/auth/infrastructure/auth_module_test.dart:48:3 • The value of the local variable
            'mockAuthenticationApiClient' isn't used.
    warning • test/core/user/infrastructure/user_api_client_test.dart:1:8 • Unused import:
            'dart:convert'.
    ```
    
    All these errors must be fixed as part of Cycle 4:
    - Update mock generations in dio_factory_test.dart and auth_module_integration_test.dart
    - Remove unused imports
    - Fix variable usage
    - This will require running `flutter pub run build_runner build --delete-conflicting-outputs` again

### Cycle 4: Update AuthService Interface and Implementation

#### 4.1 RED: Update AuthService Tests
- [x] Modify AuthService tests to reflect the updated dependency structure
- [x] Set expectations for both clients being used for their respective methods
- [x] Run tests to confirm they fail (RED)

**Insights:**
- Updated `auth_service_impl_test.dart` to use both new clients instead of the single `AuthApiClient`
- Modified the test setup to inject both `AuthenticationApiClient` and `UserApiClient`
- Ensured tests verify that login calls go to `AuthenticationApiClient` and profile calls go to `UserApiClient`
- Some tests initially passed because the mocks were accepting any calls

#### 4.2 GREEN: Update AuthServiceImpl
- [x] Modify AuthServiceImpl to inject both new clients
- [x] Update method implementations to call the correct client
- [x] Run tests to verify they pass (GREEN)

**Insights:**
- Updated `AuthServiceImpl` constructor to accept both clients
- Modified `login` and `refreshSession` to use `authenticationApiClient`
- Updated `getUserProfile` to use `userApiClient`
- Updated the dependency injection setup in `auth_module.dart` to register the implementation with both new clients

#### 4.3 REFACTOR: Clean Up Service Implementation
- [x] Improve error handling
- [x] Add documentation
- [x] Verify tests still pass

**Insights:**
- Updated the class documentation to clarify the Split Client pattern
- Ensured both clients are properly documented with their responsibilities
- Fixed issues in integration tests that were still using the old pattern
- Updated the `auth_flow_test.dart` to separately test that each client is used for its intended purpose
- Added a new test that explicitly verifies `basicDio` is used for login and `authenticatedDio` is used for profile

**Guidance for the next developer (Cycle 5):**
1. When implementing Legacy Compatibility in Cycle 5, the `AuthApiClient` should delegate to the appropriate specialized client:
   ```dart
   // In AuthApiClient (legacy)
   Future<UserProfileDto> getUserProfile() {
     return getIt<UserApiClient>().getUserProfile();
   }
   
   Future<AuthResponseDto> login(String email, String password) {
     return getIt<AuthenticationApiClient>().login(email, password);
   }
   ```

2. Be careful with any circular dependencies when implementing the legacy compatibility layer. The pattern used in this cycle (Split Client pattern) should be maintained.

3. When updating tests, focus on verifying the correct delegation rather than duplicating functionality tests.

4. Add proper deprecation notices to the legacy `AuthApiClient` to encourage migration.

5. In your tests, verify that the expected Dio instance is used for each request type.

### Cycle 5: Handle Smooth Transition (Legacy Support)

#### 5.1 RED: Create Legacy Compatibility Tests
- [x] ~~Create tests that verify the old AuthApiClient still works if used~~
- [x] ~~Test that it forwards calls to the correct new client~~
- [x] ~~Run tests to confirm they fail (RED)~~

**Insights:**
- After assessing the development status of the app, we've determined that legacy support isn't necessary since:
  - The app is still in development without any production deployments
  - Direct migration to the new split client architecture is cleaner 
  - Maintaining legacy code would introduce unnecessary technical debt
  - Forcing immediate updates prevents hidden bugs from delegation approaches

#### 5.2 GREEN: Remove Legacy AuthApiClient
- [x] Identify all references to AuthApiClient in the codebase
  - Classes to update:
    - `DioFactory`: Already updated to use `AuthenticationApiClient` instead of `AuthApiClient`
    - `AuthModule`: Need to remove the legacy registration of `AuthApiClient`
    - Tests: Several tests refer to `AuthApiClient` and need updating
      - `auth_module_test.dart`: Already using the new clients
      - `auth_module_integration_test.dart`: Needs updating
      - `dio_factory_test.dart`: Needs updating (multiple references)
    - Documentation: Update auth architecture docs to reflect split client pattern
  - Note: The actual `AuthApiClient` class in `lib/core/auth/infrastructure/auth_api_client.dart` needs to be completely removed
- [x] Replace with appropriate client (AuthenticationApiClient or UserApiClient)
  - Removed the legacy registration of `AuthApiClient` from `AuthModule`
  - Confirmed `AuthServiceImpl` already uses the new split clients
  - `DioFactory` already updated to use `AuthenticationApiClient`
- [x] Remove the AuthApiClient class entirely
  - Deleted the file `lib/core/auth/infrastructure/auth_api_client.dart`
- [ ] Run tests to verify they pass (GREEN)
  - Tests failing due to missing AuthApiClient (as expected):
    - `auth_api_client_test.dart`: Should be split into separate tests for each client
    - `auth_circular_dependency_test.dart`: Needs rework to test with new clients
    - `auth_interceptor_test.dart`: MockAuthApiClient references need updating
    - `auth_module_integration_test.dart`: References to AuthApiClient need changing
    - `auth_module_test.dart`: Failing tests need updating to use split clients
    - `authentication_api_client_test.dart`: Failing due to compiler error

**Insights:**
- The refactoring to the split client architecture was mostly completed in earlier cycles
- The legacy `AuthApiClient` registration in `AuthModule` was unnecessary since refactored components already use the new clients
- Removing the class entirely requires updating several tests that still reference the old API client
- This clean removal approach forces immediate updates to all dependencies, preventing any hidden bugs that might occur with a delegation approach
- Remaining work is focused on test fixes; the core application logic already uses the new architecture
- Given the substantial scope of test fixes needed across multiple files, this should be handled as a focused effort in Cycle 5.3

#### 5.3 REFACTOR: Clean Up After Removal
- [ ] Update failing tests to use the split client architecture
  - Focus areas:
    - Create test plan for each failing test file
    - Update tests to import the right client for each operation
    - Fix all mock generation with updated imports
    - Regenerate mocks with `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Update imports in any other files that may reference AuthApiClient
- [ ] Update documentation to reflect the new architecture
- [ ] Ensure all tests still pass

**Transition Plan to Next Developer:**
1. The core application functionality has been successfully migrated to the split client architecture
2. Production code now properly uses AuthenticationApiClient for auth operations and UserApiClient for profile operations
3. DI setup has been updated to inject the correct dependencies
4. Next step is to fix the failing tests by updating them to use the new clients
5. This refactoring is large enough that it may warrant a separate dedicated task rather than being part of this cycle

**Proposed Approach for Test Fixes:**
1. For `auth_api_client_test.dart`: Split into two new test files
   - Create `authentication_api_client_test.dart` for login and token tests
   - Create `user_api_client_test.dart` for profile tests
   - Reuse existing test logic but update to use the appropriate client

2. For `auth_circular_dependency_test.dart`: Rename and update
   - Focus on testing that the function-based DI pattern still works
   - Use AuthenticationApiClient instead of the legacy client

3. For remaining test files: Update imports and references
   - Update based on which client operations are being tested
   - Use AuthenticationApiClient for auth operations
   - Use UserApiClient for profile operations

### Cycle 5 Summary

**Completed:**
- [x] Assessed the need for legacy support and made the decision to completely remove AuthApiClient instead
- [x] Identified all references to AuthApiClient in the codebase
- [x] Removed the legacy registration of AuthApiClient from AuthModule
- [x] Deleted the AuthApiClient class entirely
- [x] Ran tests to identify all files that need updating
- [x] Created a detailed plan for updating failing tests

**Findings:**
1. The core application was already mostly migrated to the split client architecture
2. The main production code (AuthServiceImpl, DioFactory) already used the new clients
3. Removing AuthApiClient entirely exposed all places still referencing it
4. This approach forces a complete migration rather than maintaining backward compatibility
5. The failing tests need substantial updates to use the new architecture

**Next Steps:**
1. Update each failing test file to use the appropriate client based on what it's testing
2. Update documentation to reflect the new architecture
3. Regenerate mock files as needed
4. Run all tests to confirm everything works with the new architecture

The refactoring decision to fully remove the legacy AuthApiClient rather than implementing a delegation pattern was appropriate since:
1. The app is still in development without any production deployments
2. A clean break forces proper architectural updates throughout the codebase
3. No risk of unknown code paths using the legacy client
4. Simpler DI setup without unnecessary legacy support code

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