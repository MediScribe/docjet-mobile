# Archive: Original Detailed Steps for Cycle 10

This document preserves the original, more detailed steps from Cycle 10 of the offline profile caching refactoring (`docs/current/refactoring/offline-profile-cache-todo.md`) for historical reference.

* 10.2. [ ] **Tests RED –** Add integration test for authentication with network failures:
  * Update `auth_notifier_test.dart` with these test cases:
    * Mock `isAuthenticated(validateTokenLocally: false)` to return `true`
    * Mock `getUserProfile()` to throw `DioException` with each connection error type
    * Verify `_tryOfflineAwareAuthentication()` is called (or verify state transitions to offline authenticated)
    * Test with both `AuthException.offlineOperation` and DioExceptions
    * Ensure mock token and cached profile is valid to verify path works end-to-end
  * Run tests and verify they fail (RED) since the code doesn't handle these cases yet

* 10.3. [ ] **Implement GREEN –** Fix the offline fallback mechanism:
  * Rename `_checkAuthStatus()` to `checkAuthStatus()` (remove underscore) for public access and testing
  * In `checkAuthStatus()`, find the network error handler around line 440 and modify:
    ```dart
    // Inside try/catch after "try fetching profile from server"
    on DioException catch (e, s) {
      // On network-related errors, fall back to offline auth
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        _logger.w(
          '$_tag Network error during initial profile fetch, falling back to offline auth',
        );
        await _tryOfflineAwareAuthentication();
      } else {
        state = _mapDioExceptionToState(e, s, context: 'initial profile fetch');
      }
    }
    on AuthException catch (e, s) {
      // On offline operation errors, fall back to offline auth
      if (e.type == AuthErrorType.offlineOperation) {
        _logger.w(
          '$_tag Offline error during initial profile fetch, falling back to offline auth',
        );
        await _tryOfflineAwareAuthentication();
      } else {
        state = _mapAuthExceptionToState(e, s, context: 'initial profile fetch');
      }
    }
    ```
  * Update any internal calls to `_checkAuthStatus()` to use the new public name
  * Fix any tests that might be directly calling the now-renamed method
  * Run tests to verify they now pass (GREEN)

* 10.4. [ ] **Refactor –** Clean up and log improvements:
  * Extract the network error detection into a helper method:
    ```dart
    bool _isNetworkError(DioExceptionType type) {
      return type == DioExceptionType.connectionError ||
             type == DioExceptionType.sendTimeout ||
             type == DioExceptionType.receiveTimeout ||
             type == DioExceptionType.connectionTimeout;
    }
    ```
  * Update log messages to be more specific about which type of network error occurred
  * Consider adding a brief timer/debounce to avoid multiple fallback attempts if errors happen in quick succession
  * Ensure logging is consistent across all error branches

* 10.5. [ ] **Run Tests –** Verify integrations:
  * `./scripts/list_failed_tests.dart authNotifier --except`: Run the auth notifier tests with detailed error reporting
  * `./scripts/list_failed_tests.dart --except`: Verify ALL tests still pass throughout the app
  * Do a focused debugging session during app startup, verify logs show correct offline fallback path

* 10.6. [ ] **Docs Update –** Document the improved offline fallback flow:
  * Update `feature-auth-architecture.md` flow diagram to show the network error -> offline path
  * Add a section explaining "Two-stage Authentication" with:
    1. Fast online check (`isAuthenticated(validateTokenLocally: false)`)
    2. Profile fetch with network error fallback to offline
    3. Explicit offline mode when needed but still authenticated
  * Add a troubleshooting section: "What happens when server is down but user has valid tokens?"

* 10.7. [ ] **Handover –** Verify with real devices:
  * Test on physical device with airplane mode on after the app has previously authenticated
  * Test in emulator with network connection disabled while app is running
  * Verify the global offline banner appears but user remains authenticated
  * Try basic app features to ensure they're available in read-only/offline mode
  * Document findings: "With this change, users with valid cached credentials now remain authenticated even when the server is completely unreachable during startup, providing seamless offline access to cached data." 