# Auth Issues TDD Plan (Revised++)

## Problem Summary:

Login failed initially with a misleading "Invalid email or password" error. The actual root causes identified were:
1.  Mock server returned 401 due to a missing `x-api-key` header.
2.  The missing header was caused by incorrect Dio instance injection (`basicDio` used instead of `authenticatedDio`).
3.  The request URL was malformed (e.g., `.../api/v1auth/login` instead of `.../api/v1/auth/login`).

Fixing the DI and URL issues introduced a circular dependency (`AuthApiClient` <-> `AuthInterceptor`) and broke tests.

**Current State:** Code has been reverted to the state *before* attempting fixes for the URL path and DI/API key issues.

**Important Context (Commit `6a9b6a4...`):**

*   A previous refactoring (commit `6a9b6a4...`) modified `AuthApiClient` to stop adding the `x-api-key` header itself.
*   Instead, it now relies *entirely* on a Dio interceptor (configured during DI) to inject this header.
*   This change likely caused the recent failures in `auth_api_client_test.dart` because the test setup didn't mimic the interceptor, creating a mismatch (now fixed in the test file).
*   This refactoring also makes the correct DI setup (addressed in Phase 2) absolutely critical. If the interceptor isn't properly configured and injected via `authenticatedDio`, the API key *will* be missing at runtime, as `AuthApiClient` no longer provides a fallback.

## Hard Bob TDD Plan:

- [x] 1. **Phase 0: Fast Integration Test FIRST**
  - [x] 1.1. **Goal:** Create a lightweight integration test to quickly verify auth problems without running the full app
  - [x] 1.2. **Action:** Create `test/integration/auth_url_formation_test.dart`:
  ```dart
  test('integration_test_url_formation', () async {
    // 1. Setup minimal DI container
    final getIt = GetIt.instance;

    // 2. Create a local HTTP server that logs request details
    final server = await createTestServer();

    try {
      // 3. Register minimal components needed
      getIt.registerSingleton<AppConfig>(
        AppConfig.development(apiDomain: 'localhost:${server.port}')
      );
      // Register other necessary components

      // 4. Attempt login using the registered AuthApiClient
      final authClient = getIt<AuthApiClient>();
      await authClient.login('test@example.com', 'password').catchError((_) {});

      // 5. Assert on captured request from test server
      final request = server.lastRequest;
      expect(request.uri.path, contains('/api/v1/auth/login')); // Verify correct path
      expect(request.headers['x-api-key'], isNotNull); // Verify API key presence
    } finally {
      await server.close();
      await getIt.reset();
    }
  });
  ```
  - [x] 1.3. **Verification:** Test fails, showing URL formation and/or API key issues

  ### Findings from Phase 0:
  - The integration test revealed that the url was incorrectly formed: `auth/login` without base URL
  - The fix includes properly configuring Dio with a proper base URL: `http://localhost:[port]/api/v1/`
  - This confirms issue #3 in the Problem Summary: the request URL was malformed
  - With the fix in place, proper URL paths with correct slashes are formed: `/api/v1/auth/login`
  - Also confirmed the API key is properly included in the headers when configured

- [x] 2. **Phase 1: Clear Assignment of API Key Responsibility**
  - [x] 2.1. **RED/Confirm:** Confirmed `AuthApiClient` relies on DI/Interceptor for API key (Option B) via code inspection (`AuthApiClient`, `DioFactory`) and validated by successful integration test (`auth_url_formation_test.dart`). No new failing test needed.
  - [x] 2.2. **GREEN/Clarify:** Added JSDoc to `AuthApiClient` explicitly stating reliance on injected `httpClient` interceptors for API key and token handling.
  - [x] 2.3. **REFACTOR/Document:** Updated `docs/current/feature-auth-architecture.md` (diagram and text) to reflect that `DioFactory` configures the interceptor responsible for the `x-api-key` header, not `AuthApiClient`.

- [x] 3. **Phase 2: Fix URL Path Issue (`/` missing)**
  - [x] 3.1. **RED:** Created test using Dio's RequestOptions to verify URL resolution behavior with different slash combinations
  - [x] 3.2. **GREEN:** Implemented robust URL path handling
    - [x] 3.2.1. Added a `joinPaths` utility function to `ApiConfig` that handles slash normalization
    - [x] 3.2.2. Modified `baseUrlFromDomain` to include a trailing slash, helping Dio properly resolve paths
    - [x] 3.2.3. Updated all `fullEndpoint` methods to use `joinPaths` instead of string concatenation
  - [x] 3.3. **REFACTOR:** Updated tests to reflect the trailing slash in base URLs and added tests for the new utility function
  
  ### Findings from Phase 2:
  - The root cause was that when Dio uses a path without a leading slash against a baseUrl without a trailing slash, the path gets appended directly, causing malformed URLs
  - The integration test confirmed that with the trailing slash in the base URL, Dio correctly forms the full URL even when endpoint constants don't have leading slashes
  - The new `joinPaths` utility function makes URL path joining robust regardless of trailing/leading slash presence in the components

- [x] 4. **Phase 3: Break Circular Dependency**
  - [x] 4.1. **RED:** Created test showing circular dependency issue
  - [x] 4.2. **GREEN:** Implemented function-based DI
    ```dart
    // In AuthInterceptor constructor
    AuthInterceptor({
      required Future<AuthResponseDto> Function(String) refreshTokenFunction,
      required this.credentialsProvider,
      required this.dio,
      required this.authEventBus,
    }) : _refreshTokenFunction = refreshTokenFunction;
    
    // Use in onError
    final authResponse = await _refreshTokenFunction(refreshToken);
    ```
  - [x] 4.3. **REFACTOR:** Fix DioFactory and AuthModule
    ```dart
    // In DioFactory
    dio.interceptors.add(
      AuthInterceptor(
        refreshTokenFunction: (refreshToken) => 
          authApiClient.refreshToken(refreshToken),
        credentialsProvider: credentialsProvider,
        dio: dio,
        authEventBus: authEventBus,
      ),
    );
    ```
  - [x] 4.4. Updated all affected code with enhanced documentation about registration order

  ### Findings from Phase 3:
  - The circular dependency was successfully broken by using function-based DI
  - Instead of directly injecting the AuthApiClient into the AuthInterceptor, we now pass a function reference to the specific method needed (refreshToken)
  - This allows the DI container to properly resolve dependencies without circular references
  - The registration order in AuthModule is now clearly documented to avoid future issues
  - The test confirms we can now safely create an AuthApiClient that uses an authenticatedDio with AuthInterceptor

- [x] 5. **Phase 4: Improve Error Messages**
  - [x] 5.1. **RED:** Created failing tests for specific error scenarios
    - [x] 5.1.1. Test for missing API key detection in 401 errors
    - [x] 5.1.2. Test for malformed URL paths causing 404 errors
    - [x] 5.1.3. Test for improved context in network error messages
  - [x] 5.2. **GREEN:** Enhanced error handling in `AuthApiClient._handleDioException`
    - [x] 5.2.1. Check for missing API key before default 401 handling
    - [x] 5.2.2. Add specific message for URL path errors (404s)
    - [x] 5.2.3. Provide more context in network errors by including request path
  - [x] 5.3. **REFACTOR:** Ensure error messages are consistent across all code paths
    - [x] 5.3.1. Added new AuthErrorType entries for missingApiKey and malformedUrl
    - [x] 5.3.2. Enhanced AuthException factory methods to accept path parameters
    - [x] 5.3.3. Updated tests with precise assertions using factory methods
  
  ### Findings from Phase 4:
  - Error messages now provide much more context, making debugging easier:
    - Network errors include the requested path: "Network error occurred (path: auth/login)"
    - Server errors include both status code and path: "Server error occurred (500) (path: auth/login)"
    - Missing API key errors clearly indicate the issue: "API key is missing for endpoint auth/login - check your app configuration"
    - Malformed URL errors point to the specific problem: "URL path error: /api/v1auth/login might be malformed - check path formatting"
  - The enhanced error handling detects common API key and URL formation issues automatically
  - The more specific error messages help distinguish between similar error types (e.g., network vs. server vs. auth errors)
  - Tests were updated to use precise factory method assertions rather than generic string matching
  - Additional improvements based on feedback:
    - Original stack traces are now preserved in all exceptions for better debugging
    - Added a new `exactlyEquals` method to allow more precise equality checks when needed
    - Added a `diagnosticString` method that includes stack trace for detailed logging
    - Created a centralized `fromStatusCode` factory method that provides consistent error type assignment
    - Comprehensive test suite with 23+ tests for AuthException functionality

- [x] 6. **Phase 5: Final Integration Test**
  - [x] 6.1. Create a new integration test that verifies all issues are fixed. Look for existing ones, so that we don't create random new files.
  - [x] 6.2. Only run `./scripts/run_with_mock.sh` as final confirmation

- [ ] 7. **Documentation**
  - [ ] 7.1. Update `docs/current/feature-auth-architecture.md` to reflect new design
  - [ ] 7.2. Add a section on troubleshooting common auth issues 