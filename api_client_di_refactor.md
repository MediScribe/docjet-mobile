# API Client DI Refactoring Plan

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

## Findings

1. `AuthApiClient` currently handles mixed auth contexts:
   - Login/refresh (no auth required) 
   - User profile (JWT required)

2. Registration in `AuthModule` links `AuthApiClient` with `basicDio` only:
   ```dart
   getIt.registerLazySingleton<AuthApiClient>(
     () => AuthApiClient(
       httpClient: getIt<Dio>(instanceName: 'basicDio'),
       credentialsProvider: finalCredentialsProvider,
     ),
   );
   ```

3. The `AuthInterceptor` (which adds JWT) is only added to `authenticatedDio`, not `basicDio`

4. There's a function-based DI approach for token refresh, where `AuthApiClient.refreshToken` is passed to `AuthInterceptor` to break circular dependencies

## Approach: Split Client Architecture

We'll implement the "Split Client" approach as it provides the cleanest separation of concerns:

- `AuthenticationApiClient` - Handles login/refresh with `basicDio`
- `UserApiClient` - Handles user profile with `authenticatedDio`
- Modified services to use the correct clients

## Implementation Plan

### 1. Create New API Clients

- [ ] **1.1.** Create `lib/core/auth/infrastructure/authentication_api_client.dart`
   - [ ] 1.1.1. Migrate login and refresh token methods from `AuthApiClient`
   - [ ] 1.1.2. Inject `basicDio` and `credentialsProvider`
   - [ ] 1.1.3. Adapt error handling for authentication-specific cases

- [ ] **1.2.** Create `lib/core/user/infrastructure/user_api_client.dart`
   - [ ] 1.2.1. Create directory structure if needed
   - [ ] 1.2.2. Migrate `getUserProfile` method from `AuthApiClient`
   - [ ] 1.2.3. Inject `authenticatedDio` and any other dependencies
   - [ ] 1.2.4. Adapt error handling for user-specific cases

### 2. Update DI Registration

- [ ] **2.1.** Modify `AuthModule` in `lib/core/auth/infrastructure/auth_module.dart`
   - [ ] 2.1.1. Register `AuthenticationApiClient` with `basicDio`
   - [ ] 2.1.2. Register `UserApiClient` with `authenticatedDio`
   - [ ] 2.1.3. Handle circular dependency for token refresh function
   - [ ] 2.1.4. Update ordering of registrations to maintain dependency flow

- [ ] **2.2.** Create `UserModule` if doesn't exist
   - [ ] 2.2.1. Create module structure if needed
   - [ ] 2.2.2. Add necessary registrations for user-related services

### 3. Update Service Layer

- [ ] **3.1.** Modify `AuthService` interface in `lib/core/auth/auth_service.dart` if needed
   - [ ] 3.1.1. Review method signatures for any changes
   - [ ] 3.1.2. Add new methods or modify existing ones as needed

- [ ] **3.2.** Update `AuthServiceImpl` in `lib/core/auth/infrastructure/auth_service_impl.dart`
   - [ ] 3.2.1. Inject both API clients
   - [ ] 3.2.2. Route method calls to appropriate clients
   - [ ] 3.2.3. Update method implementations
   - [ ] 3.2.4. Maintain error handling and event emission

### 4. Update Tests

- [ ] **4.1.** Fix `auth_module_test.dart`
   - [ ] 4.1.1. Update test expectations for new DI structure
   - [ ] 4.1.2. Fix the failing test for "getUserProfile needs AuthInterceptor"
   - [ ] 4.1.3. Fix the failing test for "Fixed AuthApiClient"

- [ ] **4.2.** Create new test files
   - [ ] 4.2.1. Create `test/core/auth/infrastructure/authentication_api_client_test.dart`
   - [ ] 4.2.2. Create `test/core/user/infrastructure/user_api_client_test.dart`
   - [ ] 4.2.3. Migrate and adapt tests from `auth_api_client_test.dart`

- [ ] **4.3.** Update mocks and test utilities
   - [ ] 4.3.1. Create new mock classes for the new clients
   - [ ] 4.3.2. Update existing tests that mock `AuthApiClient`

### 5. Update AuthInterceptor

- [ ] **5.1.** Review and update `AuthInterceptor` in `lib/core/auth/infrastructure/auth_interceptor.dart`
   - [ ] 5.1.1. Update token refresh function reference to point to new `AuthenticationApiClient`
   - [ ] 5.1.2. Ensure no circular dependencies are introduced

### 6. Cleanup and Documentation

- [ ] **6.1.** Mark old `AuthApiClient` as deprecated
   - [ ] 6.1.1. Add `@deprecated` annotation
   - [ ] 6.1.2. Add migration documentation
   - [ ] 6.1.3. Plan for eventual removal

- [ ] **6.2.** Update documentation
   - [ ] 6.2.1. Update class documentation with authentication context
   - [ ] 6.2.2. Document DI changes in `AuthModule`
   - [ ] 6.2.3. Update ADRs if applicable

### 7. Verification

- [ ] **7.1.** Run all tests
   - [ ] 7.1.1. Run `./scripts/list_failed_tests.dart`
   - [ ] 7.1.2. Fix any newly introduced failures

- [ ] **7.2.** Verify application functionality
   - [ ] 7.2.1. Test login flow manually
   - [ ] 7.2.2. Test profile retrieval manually
   - [ ] 7.2.3. Verify error handling for invalid credentials

## Risks and Mitigations

1. **Risk:** Breaking changes to service interfaces
   **Mitigation:** Maintain backward compatibility or update all call sites

2. **Risk:** Circular dependencies in DI
   **Mitigation:** Use function-based DI as currently done with token refresh

3. **Risk:** Regression in error handling
   **Mitigation:** Comprehensive testing of error cases 

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