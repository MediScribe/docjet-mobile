# Auth Issues TDD Plan (Revised+)

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

- [ ] 1. **Update Documentation:**
  - [ ] 1.1. **Action:** Update `docs/current/feature-auth-architecture.md` (diagrams and text) to reflect that the API key (`x-api-key`) is injected by an interceptor within `DioFactory` based on `AppConfig`, *not* fetched from `AuthCredentialsProvider` by `AuthApiClient`.
  - [ ] 1.2. **Verification:** The document accurately describes the current implementation.

- [ ] 2. **Phase 0: Baseline**
  - [ ] 2.1. **Objective:** Understand the starting point after reverts.
  - [ ] 2.2. **Action:**
    - [ ] 2.2.1. Run `dart analyze`. Note any existing errors.
    - [ ] 2.2.2. Run `./scripts/list_failed_tests.dart`. Note any failing tests.
  - [ ] 2.3. **Verification:** We have a clear picture of the initial (presumably broken) state.

- [ ] 3. **Phase 1: Fix URL Path Issue (`/` missing)**
  - [ ] 3.1. **RED:**
    - [ ] 3.1.1. **Goal:** Create a failing test showing `v1auth/login` instead of `v1/auth/login`.
    - [ ] 3.1.2. **Hypothesis:** The combination of `ApiConfig.baseUrlFromDomain` (no trailing slash) and `ApiConfig.loginEndpoint` (no leading slash) causes Dio to concatenate incorrectly.
    - [ ] 3.1.3. **Action:** Write/modify a unit test in `test/core/config/api_config_test.dart`. Simulate Dio's path joining (e.g., `baseUrl + endpointPath`). Assert the result *is* the malformed path and *is not* the correct path.
    - [ ] 3.1.4. **Verification:** The test fails.
  - [ ] 3.2. **GREEN:**
    - [ ] 3.2.1. **Goal:** Make the failing URL test pass.
    - [ ] 3.2.2. **Action:** Add leading slashes to *all* endpoint constants in `lib/core/config/api_config.dart`.
    - [ ] 3.2.3. **Verification:** Re-run the specific failing test from step 3.1. It must pass. Run `dart analyze lib/core/config/api_config.dart`.
  - [ ] 3.3. **REFACTOR:**
    - [ ] 3.3.1. **Goal:** Clean up `ApiConfig.dart` or the test.
    - [ ] 3.3.2. **Action:** Review changes for clarity. (Likely none needed).
    - [ ] 3.3.3. **Verification:** Tests still pass. `dart analyze` clean on modified files.

- [ ] 4. **Phase 2: Break Circular Dependency & Fix DI**
  - [ ] 4.1. **RED:**
    - [ ] 4.1.1. **Goal:** Create a failing test showing the circular dependency issue.
    - [ ] 4.1.2. **Action:** Create unit test in `test/core/auth/infrastructure/auth_interceptor_test.dart` that demonstrates:
        *   Current: `AuthInterceptor` requires `AuthApiClient` directly
        *   Expected: `AuthInterceptor` should only need a token refresh function, not the entire client
    - [ ] 4.1.3. **Verification:** Test fails, showing tight coupling between interceptor and API client.
  - [ ] 4.2. **GREEN:**
    - [ ] 4.2.1. **Goal:** Refactor `AuthInterceptor` to use function-based DI to break circular dependency.
    - [ ] 4.2.2. **Action:**
        - [ ] 4.2.2.1. Refactor `AuthInterceptor` to accept a token refresh function instead of `AuthApiClient`:
        ```dart
        class AuthInterceptor extends Interceptor {
          // Replace direct dependency:
          // final AuthApiClient apiClient;

          // With function reference:
          final Future<AuthResponseDto> Function(String refreshToken) refreshTokenFunction;

          AuthInterceptor({
            required this.refreshTokenFunction, // NEW
            required this.credentialsProvider,
            required this.dio,
            required this.authEventBus,
          });

          // Update onError method to use refreshTokenFunction instead of apiClient:
          // final authResponse = await apiClient.refreshToken(refreshToken);
          // Becomes:
          // final authResponse = await refreshTokenFunction(refreshToken);
        }
        ```
        - [ ] 4.2.2.2. Update `DioFactory.createAuthenticatedDio` to accept this function instead of the client:
        ```dart
        Dio createAuthenticatedDio({
          required Future<AuthResponseDto> Function(String) refreshTokenFunction,
          required AuthCredentialsProvider credentialsProvider,
          required AuthEventBus authEventBus,
        }) {
          // ...
          dio.interceptors.add(
            AuthInterceptor(
              refreshTokenFunction: refreshTokenFunction,
              credentialsProvider: credentialsProvider,
              dio: dio,
              authEventBus: authEventBus,
            ),
          );
          // ...
        }
        ```
        - [ ] 4.2.2.3. Modify `AuthModule.register` to break the circular dependency:
        ```dart
        // First register AuthApiClient with basicDio
        getIt.registerLazySingleton<AuthApiClient>(() => AuthApiClient(
          httpClient: getIt<Dio>(instanceName: 'basicDio'),
          credentialsProvider: finalCredentialsProvider,
        ));

        // Then register authenticatedDio using a function reference to the refresh method
        getIt.registerLazySingleton<Dio>(() {
          return _dioFactory.createAuthenticatedDio(
            refreshTokenFunction: (refreshToken) =>
              getIt<AuthApiClient>().refreshToken(refreshToken),
            credentialsProvider: finalCredentialsProvider,
            authEventBus: finalAuthEventBus,
          );
        }, instanceName: 'authenticatedDio');
        ```
    - [ ] 4.2.3. **Verification:** Re-run the failing test from step 4.1. It must pass. Run `dart analyze` on modified files.
  - [ ] 4.3. **REFACTOR (Fix Test Fallout):**
    - [ ] 4.3.1. **Goal:** Get *entire test suite* green & `dart analyze` clean after DI refactor.
    - [ ] 4.3.2. **Action:** Run `dart run build_runner build --delete-conflicting-outputs`. Run `dart analyze`. Fix all analysis errors (mostly in tests). Run `./scripts/list_failed_tests.dart`. Fix all failing tests (update mocks/constructors).
    - [ ] 4.3.3. **Verification:** `dart analyze` passes. `./scripts/list_failed_tests.dart` shows no failures.

- [ ] 5. **Phase 2-Alt: Simpler API Key Injection Approach (Fallback)**
  - [ ] 5.1. If the function-based approach in Phase 2 (Item 4) is too complex, consider this alternate solution:
    - [ ] 5.1.1. Ensure `AuthApiClient` properly handles API key injection itself rather than relying on an interceptor.
    - [ ] 5.1.2. Keep `AuthInterceptor` focused only on auth token handling, not API keys.
    - [ ] 5.1.3. This removes the circular dependency as both components have clear, separate responsibilities.

- [ ] 6. **Phase 3: Fast Integration Test Instead of Manual Verification**
  - [ ] 6.1. **Create Fast Integration Test:**
    - [ ] 6.1.1. **Goal:** Verify URL formation and header injection without running the full app.
    - [ ] 6.1.2. **Action:** Create a focused test in `test/integration/auth_url_formation_test.dart`:
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
        // Register other necessary components like AuthCredentialsProvider, AuthEventBus, DioFactory, AuthApiClient etc. correctly

        // 4. Attempt login using the registered AuthApiClient
        final authClient = getIt<AuthApiClient>();
        await authClient.login('test@example.com', 'password'); // Use actual methods

        // 5. Assert on captured request from test server
        final request = server.lastRequest; // Assuming server captures last request
        expect(request.uri.path, contains('/api/v1/auth/login')); // Verify correct path
        expect(request.headers['x-api-key'], isNotNull); // Verify API key presence
        // Optionally check Bearer token if login implies immediate auth:
        // expect(request.headers['Authorization'], startsWith('Bearer '));
      } finally {
        await server.close();
        await getIt.reset(); // Clean up GetIt
      }
    });
    ```
    - [ ] 6.1.3. **Verification:** Test runs quickly (seconds, not minutes) and passes, with no need for slow manual app startup.
  - [ ] 6.2. **Runtime Verification (If Needed):**
    - [ ] 6.2.1. Run `./scripts/run_with_mock.sh` only as a final confirmation, not for debugging.

- [ ] 7. **Phase 4: Improve Error Messages**
  - [ ] 7.1. **RED:**
    - [ ] 7.1.1. **Goal:** Test proper error messages from `AuthApiClient._handleDioException`.
    - [ ] 7.1.2. **Action:** Create a test that verifies specific error scenarios get appropriate error messages:
      * API key missing should return `AuthException.configurationError('Missing or invalid API key')` not `AuthException.invalidCredentials()`
      * Malformed URL (e.g., 404) should return `AuthException.networkError()` or a specific endpoint error, not just a generic server error.
    - [ ] 7.1.3. **Verification:** Test fails because current error mapping is too simplistic or incorrect.
  - [ ] 7.2. **GREEN:**
    - [ ] 7.2.1. **Goal:** Improve error messages for better debugging.
    - [ ] 7.2.2. **Action:** Enhance `AuthApiClient._handleDioException` to handle more specific error cases:
    ```dart
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      if (statusCode == 401) {
        // Check if this might be an API key issue (server might indicate, or context implies)
        // This logic might need refinement based on actual API responses
        if (e.requestOptions.headers['x-api-key'] == null || e.requestOptions.headers['x-api-key'] == '') {
           return AuthException.configurationError('Missing or invalid API key (client-side check)');
        }
        // If server response explicitly mentions API key problem:
        // if (e.response?.data?.toString().contains('apiKey') ?? false) {
        //   return AuthException.configurationError('Missing or invalid API key (server response)');
        // }

        if (requestPath.contains(ApiConfig.refreshEndpoint)) {
          return AuthException.refreshTokenInvalid();
        }
        // ... existing login/profile 401 handling ...
        return AuthException.invalidCredentials(); // Default 401
      } else if (statusCode == 404) {
        // Handle 404 specifically as a potential configuration/URL issue
        return AuthException.networkError('Endpoint not found: $requestPath');
      }
      // ... existing 403, 5xx handling ...
    } else {
      // Existing network/timeout/offline handling
      if (e.error is SocketException) {
         return AuthException.offlineOperationFailed();
      }
      // ... other DioException types
    }
    // Fallback
    return AuthException.unknownError(e.message ?? 'Unknown error');
    ```
    - [ ] 7.2.3. **Verification:** The specific error tests now pass.
  - [ ] 7.3. **Final Cleanup:**
    - [ ] 7.3.1. **Action:** Fix `TODO` for user ID clearing in `AuthInterceptor` (if applicable after refactor). Remove temporary debug logging.
    - [ ] 7.3.2. **Verification:** App works. Code clean. `dart analyze` clean. All tests pass. 