# Authentication Testing Guide

This document explains how to test the authentication system in DocJet Mobile.

## Testing Levels

Authentication testing is conducted at multiple levels:

1. **Unit Tests**: Testing individual components in isolation
2. **Integration Tests**: Testing interactions between components
3. **End-to-End Tests**: Testing complete flows from UI to data layer

## Unit Testing Auth Components

Unit tests focus on testing individual components in isolation:

- **AuthException**: Tests for different exception types and factory methods
- **AuthCredentialsProvider**: Tests secure storage of tokens and validation
- **JWT Validation**: Tests token validation and expiry detection
- **AuthenticationApiClient**: Tests non-authenticated operations (login, refresh) ensuring `basicDio` is used and errors are mapped correctly
- **UserApiClient**: Tests authenticated operations (profile) ensuring `authenticatedDio` is used and errors are mapped correctly
- **AuthService**: Tests implementation (`AuthServiceImpl`) verifying delegation to the correct API client (`AuthenticationApiClient` or `UserApiClient`) based on the method called
- **AuthInterceptor**: Tests token refresh logic, ensuring it correctly uses the provided `refreshTokenFunction` (from `AuthenticationApiClient`) and handles 401s appropriately for requests made via `authenticatedDio`

## End-to-End Authentication Flow Testing

End-to-end tests validate the complete authentication flow. Our approach uses mock UI components to isolate testing from real UI implementation details while still validating the full flow.

### File Location

The end-to-end authentication tests are located at: `test/e2e/auth_flow_test.dart`

### Key Flows Tested

1. **Login Flow**: User can log in and navigate to the authenticated screen
   - Test enters credentials and submits login form
   - Verifies loading state is shown during login
   - Verifies successful navigation to home screen with user details

2. **Token Refresh**: Verifies token refresh mechanism works
   - Tests that expired tokens are refreshed automatically
   - Verifies that original requests succeed after refresh

3. **Logout Flow**: User can log out and return to login screen
   - Tests that logout button works
   - Verifies navigation back to login screen
   - Verifies auth state is reset

### Test Architecture

The tests use a specialized testing infrastructure:

1. **MockLoginScreen & MockHomeScreen**: Lightweight UI mocks that avoid dependencies on real UI components

2. **TestAuthApp**: A test-specific app that simulates the real app's authentication flows:
   - State management for auth states
   - Navigation between screens based on auth state
   - Callbacks for login, logout, and profile fetching

3. **Mock Services**: Implementations of auth services for testing:
   - MockAuthService
   - MockAuthEventBus
   - MockAuthSessionProvider

### Running the E2E Authentication Tests

Run the end-to-end auth tests with:

```bash
flutter test test/e2e/auth_flow_test.dart
```

## Troubleshooting Common Test Issues

### Loading State Not Visible in Tests

If tests for loading states fail, ensure you're allowing sufficient frames for the loading indicator to appear:

```dart
// Tap action that triggers loading
await tester.tap(find.text('Login')); 

// Process first frame
await tester.pump();

// Wait for loading state to appear
await tester.pump(const Duration(milliseconds: 100)); 

// Now test for loading indicator
expect(find.byType(CircularProgressIndicator), findsOneWidget);
```

### Widget Not Found Errors

If tests can't find widgets, check:

1. Widget hierarchy - ensure widgets are actually rendered
2. Text matching - check for exact text matching
3. Timing - ensure sufficient pump calls for async operations

### Dependency Errors

If tests fail with dependency errors:

1. Use TestAuthApp which avoids real dependencies
2. Provide all required mock implementations
3. Don't rely on actual GetIt or ProviderScope dependencies in tests 

## Testing Offline Authentication

The offline authentication system requires comprehensive testing to ensure users can remain authenticated and access critical functionality when offline, while also ensuring token validation with the server when connectivity is restored.

### Offline Authentication Test Cases

Our test suite includes the following key test cases for offline authentication:

1. **Offline Authentication with Valid Local Tokens**:
   - Test file: `test/core/auth/presentation/auth_notifier_test.dart`
   - Verifies that users with valid local tokens remain authenticated when offline
   - Checks that the `isOffline` flag is properly set in the auth state
   - Confirms that the system uses the cached profile when online fetch fails

2. **Token Validation on Network Restoration**:
   - Test file: `test/core/auth/presentation/auth_notifier_test.dart`
   - Verifies that tokens are validated with the server when network is restored
   - Confirms proper state transition to unauthenticated state if server rejects the token
   - Ensures fresh profile data is fetched and cached when token is valid

3. **Corrupted Profile Cache Handling**:
   - Test file: `test/core/auth/presentation/corrupted_cache_test.dart`
   - Tests system behavior when encountering corrupted profile cache
   - Verifies user remains authenticated with an anonymous profile
   - Checks that appropriate error notification is shown via `AppNotifierService`

4. **Token Expiry During Offline Mode**:
   - Test file: `test/core/auth/presentation/auth_notifier_test.dart`
   - Verifies correct handling of token expiry detection during offline authentication
   - Confirms transition to unauthenticated state with appropriate error when token is expired

5. **Integration with Job Feature**:
   - Test file: `test/features/jobs/data/services/job_sync_orchestrator_service_auth_events_test.dart`
   - Tests that the job synchronization feature correctly responds to authentication events
   - Verifies jobs are not synced when offline and sync resumes when online
   - Confirms in-flight operations are properly cancelled on connectivity changes

### Testing Offline Authentication Locally

To manually test offline authentication:

1. **Setup Test Environment**:
   ```bash
   flutter run --dart-define=API_KEY=your_api_key
   ```

2. **Test Offline Login Fallback**:
   - Log in to the app while online
   - Disable network connectivity (airplane mode or network settings)
   - Restart the app
   - Verify the app authenticates using cached credentials with offline indicator

3. **Test Network Restoration**:
   - While app is running in offline mode
   - Re-enable network connectivity
   - Verify the app automatically refreshes authentication with the server
   - Check that fresh profile data is loaded

4. **Test Token Expiry Handling**:
   - Modify the token validation logic temporarily to consider all tokens expired
   - Restart the app in offline mode
   - Verify app transitions to unauthenticated state with appropriate message

5. **Test Corrupted Cache Recovery**:
   - Use developer tools to manually corrupt the cached profile JSON
   - Restart the app in offline mode
   - Verify app stays authenticated with anonymous profile
   - Check that appropriate error notification is displayed

### Simulating Network Conditions

Use these approaches to reliably test different network conditions:

1. **Device Network Controls**:
   - Use airplane mode or network settings to disable all connectivity
   - Useful for testing complete offline scenarios

2. **Charles Proxy / Network Link Conditioner**:
   - Simulate poor connectivity, high latency, or intermittent network
   - Useful for testing edge cases like request timeouts during authentication

3. **Mock Network Info**:
   - In integration tests, use `MockNetworkInfo` to simulate offline state
   - Override `isConnected` to return false for offline testing
   - Example:
     ```dart
     final mockNetworkInfo = MockNetworkInfo();
     when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);
     ```

4. **Simulated Network Exceptions**:
   - For unit tests, use `thenThrow(const AuthException.offlineOperationFailed())` to simulate network failures
   - Example:
     ```dart
     when(
       mockAuthService.getUserProfile(acceptOfflineProfile: false),
     ).thenThrow(const AuthException.offlineOperationFailed());
     ```

### Troubleshooting Offline Authentication Tests

Common issues and solutions when testing offline authentication:

1. **Inconsistent Network Detection**:
   - Ensure `NetworkInfoImpl` is properly detecting network changes
   - Verify connectivity events are correctly propagated through `AuthEventBus`
   - Check that `isOffline` flag is consistently updated in auth state

2. **Cached Profile Not Being Used**:
   - Confirm the `acceptOfflineProfile` parameter is true for offline scenarios
   - Verify profile is being correctly saved to cache after successful online fetches
   - Check timestamp validation in `IUserProfileCache` implementation

3. **Token Validation Failures**:
   - Ensure `JwtValidator` is correctly checking token expiry
   - Verify both access and refresh token validation work correctly
   - Test different token states (valid, expired, malformed) in offline scenarios

4. **Missing Error Notifications**:
   - Check that `AppNotifierService` is correctly wired up in tests and implementation
   - Verify error messages are appropriate and user-friendly
   - Ensure notifications don't block critical app functionality

For detailed edge case handling, refer to the implementation in `lib/core/auth/presentation/auth_notifier.dart` and the corresponding test cases. 